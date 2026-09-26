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
/// menu — not a widget layered on top.
///
/// 🔑 Pages are never opened by URL. Every destination goes through
/// [WebSessionService], which trades the app's session for a one-time URL
/// that arrives already signed in. Opening a path directly works, but drops
/// the user on a web login screen they should never have to see.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const _tag = 'Dashboard';

  late final WebViewController _controller;
  final _webSession = WebSessionService();
  StreamSubscription<String>? _navigationSubscription;

  /// Guards the one retry after landing on the login page. Without it a
  /// bridge that keeps failing would reload forever, and each reload costs a
  /// one-time URL.
  bool _retriedAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController.fromPlatformCreationParams(
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
    _open(dashboardPath);
    _navigationSubscription = DashboardNavigation.onRequested.listen(_open);
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
    AppLog.write(_tag, 'loaded ${uri.host}${uri.path}');

    // Landing here means the webview's own cookies have expired — the app's
    // session may still be perfectly good. Trade it for a fresh one-time URL
    // rather than making the user sign in a second time.
    if (uri.host == tideHost && uri.path == loginPath && !_retriedAfterLogin) {
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
    AppLog.write(_tag, 'opening $path');
    if (path != loginPath) _retriedAfterLogin = false;

    final signedIn = await _webSession.signedInUrl(next: path);
    try {
      // No bridge available — open the path plainly and let the web login
      // screen stand in, exactly as api.md prescribes for a 500.
      await _controller.loadRequest(signedIn ?? Uri.parse('$tideBaseUrl$path'));
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
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
