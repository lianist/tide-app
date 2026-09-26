import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';

import '../services/app_log.dart';
import '../services/app_paths.dart';
import '../services/dashboard_navigation.dart';
import '../services/dochi_config.dart';
import '../services/web_session_service.dart';
import '../services/webview2_runtime.dart';
import 'webview2_missing_screen.dart';

/// The dashboard webview — one widget for both desktops.
///
/// macOS is WKWebView (`webview_flutter_wkwebview`); Windows is a real
/// WebView2 window parented over the Flutter window (`webview_win_floating`,
/// which registers itself as webview_flutter's Windows implementation). Both
/// speak the same `WebViewController` API, so the only per-platform code left
/// is the navigation policy below.
///
/// 🔑 On Windows the WebView2 is a *native child window*, not a texture, so
/// nothing Flutter draws can appear over it. Anything the dashboard needs to
/// show the user has to be part of the page, an OS notification, or the tray
/// menu — not a widget layered on top. The one exception is when there is no
/// webview at all: [WebView2MissingScreen] takes the whole window precisely
/// because nothing has been created to cover it.
///
/// 🔑 Pages are never opened by URL. Every destination goes through
/// [WebSessionService], which trades the app's session for a one-time URL
/// that arrives already signed in. Opening a path directly works, but drops
/// the user on a web login screen they should never have to see.
class DashboardView extends StatefulWidget {
  /// The user signed out (or deleted their account) inside the dashboard.
  /// Only the web session ends there; dropping the app's own is the app's job.
  final VoidCallback onSignedOut;

  const DashboardView({super.key, required this.onSignedOut});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const _tag = 'Dashboard';

  /// Null while there is no WebView2 runtime to build one with — the only
  /// reason this is nullable.
  WebViewController? _controller;
  final _webSession = WebSessionService();
  StreamSubscription<String>? _navigationSubscription;

  /// Set when the user pressed "다시 확인" and the runtime still wasn't there.
  bool _recheckFailed = false;

  /// Guards the one retry after landing on the login page. Without it a
  /// bridge that keeps failing would reload forever, and each reload costs a
  /// one-time URL.
  bool _retriedAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Creates the webview and opens the dashboard in it.
  ///
  /// Does nothing when Windows has no WebView2 runtime — building the
  /// controller then produces a blank white rectangle and no error anyone can
  /// see, which is the exact failure this checks for.
  void _start() {
    if (!WebView2Runtime.isInstalled) {
      AppLog.write(_tag, 'no WebView2 runtime — showing the install notice');
      return;
    }

    final controller = WebViewController.fromPlatformCreationParams(
      // 🔑 Windows needs the browser profile placed deliberately. Left to
      // itself WebView2 creates it *beside the executable*, which is only
      // writable by luck: not under Program Files, and never inside an MSIX
      // package, where the install folder is read-only by design. The
      // dashboard fails as a blank white rectangle when that write fails.
      Platform.isWindows
          ? WindowsWebViewControllerCreationParams(
              userDataFolder: AppPaths.webViewDataFolder,
            )
          : const PlatformWebViewControllerCreationParams(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: _handlePageFinished,
          onWebResourceError: (error) =>
              AppLog.write(_tag, 'load error: ${error.description}'),
        ),
      );

    _controller = controller;
    _open(dashboardPath);
    _navigationSubscription ??= DashboardNavigation.onRequested.listen(_open);
  }

  /// "설치했습니다 · 다시 확인" — the runtime installs while the app is still
  /// running, so the app has to be able to notice without being restarted.
  void _recheck() {
    if (!WebView2Runtime.isInstalled) {
      AppLog.write(_tag, 'rechecked — WebView2 runtime still not found');
      setState(() => _recheckFailed = true);
      return;
    }
    AppLog.write(_tag, 'WebView2 runtime found on recheck — starting the webview');
    setState(_start);
  }

  /// 🔑 On Windows, navigation is **not** policed, and deliberately so.
  ///
  /// It used to be: anything off the service's host was stopped and handed to
  /// the system browser. Sign-in is exactly the flow that breaks under that
  /// rule — a chain of redirects passes through whatever host the identity
  /// provider feels like using that day, and the first one nobody had listed
  /// got torn out of the webview mid-flow and reopened in a browser holding
  /// none of the cookies the flow depends on.
  ///
  /// WebView2 *is* Edge and presents as Edge, so there is no reason to move
  /// the flow elsewhere — and a sign-in finished elsewhere leaves its cookies
  /// there, which is the one place they are no use to the dashboard.
  ///
  /// macOS is the opposite case and keeps the old rule: WKWebView is
  /// recognisably an embedded webview and Google refuses to authenticate in
  /// one at all, so off-host navigation has to leave. (Since the web-session
  /// bridge landed, the webview should never start a sign-in at all — this is
  /// the belt to that braces.)
  FutureOr<NavigationDecision> _handleNavigation(NavigationRequest request) {
    if (Platform.isWindows) return NavigationDecision.navigate;

    final uri = Uri.tryParse(request.url);
    if (uri != null && uri.host != tideHost) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handlePageFinished(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final signedOut = uri.queryParameters.containsKey(signedOutParam);
    // 🔑 Host and path only — never the query. One of the URLs that arrives
    // here is the one-time sign-in address from the bridge, and its query is
    // a credential (`public/api.md` — 주소를 로그에 남기지 않는다). The one
    // marker worth having is added by name, not by copying what was there.
    AppLog.write(
      _tag,
      'loaded ${uri.host}${uri.path}${signedOut ? ' (signed out)' : ''}',
    );

    if (uri.host != tideHost || uri.path != loginPath) return;

    // The user pressed 로그아웃 in the dashboard, or deleted their account.
    //
    // 🔴 Bridging here would be the opposite of what they asked for: the
    // one-time URL signs the webview straight back into the account they
    // just left, and the capture shortcuts keep posting to it because the
    // app's own token never moved. The visible button has to end both
    // sessions, so this is where the app ends its own.
    if (signedOut) {
      AppLog.write(_tag, 'signed out on the web — dropping the app session too');
      widget.onSignedOut();
      return;
    }

    // No marker: the webview's own cookies merely expired, and the app's
    // session may still be perfectly good. Trade it for a fresh one-time URL
    // rather than making the user sign in a second time.
    if (!_retriedAfterLogin) {
      _retriedAfterLogin = true;
      AppLog.write(_tag, 'webview session expired — re-bridging');
      _open(dashboardPath);
    }
  }

  /// Opens a service path, signed in.
  ///
  /// The one-time URL is loaded but never logged: it carries a token that
  /// signs its holder in (`public/api.md` — 주소를 로그에 남기지 않는다). The
  /// *destination* is logged instead, which is what anyone reading the log
  /// actually wants to know.
  Future<void> _open(String path) async {
    final controller = _controller;
    if (controller == null) return;

    AppLog.write(_tag, 'opening $path');
    if (path != loginPath) _retriedAfterLogin = false;

    final signedIn = await _webSession.signedInUrl(next: path);
    try {
      // No bridge available — open the path plainly and let the web login
      // screen stand in, exactly as api.md prescribes for a 500.
      await controller.loadRequest(signedIn ?? Uri.parse('$tideBaseUrl$path'));
    } catch (e) {
      AppLog.write(_tag, 'opening $path failed: $e');
    }
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return WebView2MissingScreen(
        onRecheck: _recheck,
        stillMissing: _recheckFailed,
      );
    }
    return WebViewWidget(controller: controller);
  }
}
