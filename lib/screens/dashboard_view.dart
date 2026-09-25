import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_log.dart';
import '../services/dashboard_refresh.dart';
import 'dashboard_url.dart';

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
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const _tag = 'Dashboard';

  late final WebViewController _controller;
  StreamSubscription<void>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: _handlePageFinished,
          onWebResourceError: (error) =>
              AppLog.write(_tag, 'load error: ${error.description}'),
        ),
      )
      ..loadRequest(dashboardUri);
    // A capture that created or completed a task leaves the rendered list
    // stale; nothing in the page knows to go and look again.
    _refreshSubscription =
        DashboardRefresh.onRequested.listen((_) => _reload());
  }

  /// 🔑 On Windows, navigation is **not** policed, and deliberately so.
  ///
  /// It used to be: anything off dochi's host was stopped and handed to the
  /// system browser. Sign-in is exactly the flow that breaks under that rule.
  /// `dochi → supabase → accounts.google.com → …` is a chain of redirects that
  /// passes through whatever host Google feels like using that day (device
  /// verification, a consent screen, a captcha), and the first one nobody had
  /// listed got torn out of the webview mid-flow and reopened in a browser
  /// holding none of the cookies or OAuth state the flow depends on. That
  /// browser then sits there waiting forever, and the app window bounces back
  /// to the dashboard — which is exactly what "Google 로그인이 앱을 거치면 안
  /// 된다" looked like.
  ///
  /// WebView2 *is* Edge and presents as Edge, so there is no reason to move
  /// the flow elsewhere — and a sign-in finished elsewhere leaves its cookies
  /// there, which is the one place they are no use to the dashboard.
  ///
  /// macOS is the opposite case and keeps the old rule: WKWebView is
  /// recognisably an embedded webview and Google refuses to authenticate in
  /// one at all, so off-host navigation has to leave.
  FutureOr<NavigationDecision> _handleNavigation(NavigationRequest request) {
    if (Platform.isWindows) return NavigationDecision.navigate;

    final uri = Uri.tryParse(request.url);
    if (uri != null && uri.host != dashboardUri.host) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handlePageFinished(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    AppLog.write(_tag, 'loaded ${uri.host}${uri.path}');
    // Only dochi's own pages, and only where the problem exists.
    if (Platform.isWindows && uri.host == dashboardUri.host) {
      _controller.runJavaScript(_passwordRevealScript);
    }
  }

  Future<void> _reload() async {
    try {
      // Straight back to the dashboard rather than `reload()`: the reason to
      // refresh is a capture that changed the task list, and the user may
      // have wandered off that list since.
      await _controller.loadRequest(dashboardUri);
    } catch (e) {
      AppLog.write(_tag, 'refresh failed: $e');
    }
  }

  /// Gives dochi's login and sign-up forms a password reveal that works.
  ///
  /// WebView2 draws Edge's native reveal button (`::-ms-reveal`) inside every
  /// password field but doesn't act on it — that eye is browser-shell UI the
  /// embedded control never wires up, so clicking it does nothing at all. It
  /// is hidden here and replaced with a plain text toggle.
  ///
  /// Runs after the page is loaded (and so after hydration): the button is
  /// appended as the label's last child and the input itself is never moved,
  /// because re-parenting a node React is still tracking makes it throw and
  /// blank the page.
  static const String _passwordRevealScript = r'''
(() => {
  if (window.__tideReveal) return;
  window.__tideReveal = true;
  const SHOW = '보기';
  const HIDE = '숨기기';
  const style = document.createElement('style');
  style.textContent = 'input::-ms-reveal{display:none!important;}';
  document.head.appendChild(style);
  const decorate = (input) => {
    if (input.dataset.tideReveal) return;
    const host = input.parentElement;
    if (!host) return;
    input.dataset.tideReveal = '1';
    host.style.position = 'relative';
    input.style.paddingRight = '3.5rem';
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = SHOW;
    button.style.cssText = 'position:absolute;right:0.6rem;bottom:0.55rem;' +
      'border:0;background:none;padding:0;font:inherit;font-size:0.8125rem;' +
      'color:#6b7280;cursor:pointer;';
    button.addEventListener('click', () => {
      const reveal = input.type === 'password';
      input.type = reveal ? 'text' : 'password';
      button.textContent = reveal ? HIDE : SHOW;
    });
    host.appendChild(button);
  };
  const scan = () =>
    document.querySelectorAll('input[type=password]').forEach(decorate);
  scan();
  new MutationObserver(scan)
    .observe(document.body, {childList: true, subtree: true});
})();
''';

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
