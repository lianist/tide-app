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
  StreamSubscription<Uri>? _navigationSubscription;

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
      )
      ..loadRequest(dashboardUri);
    _navigationSubscription = DashboardNavigation.onRequested.listen(_goTo);
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
    // Only dochi's own pages — never Google's sign-in, never anywhere else
    // the webview travels.
    if (uri.host != dashboardUri.host) return;
    // The result is logged rather than dropped: "is the build I am running
    // actually the one with the login-screen fixes in it?" is otherwise only
    // answerable by squinting at the page, and that question has already
    // cost one release's worth of confusion.
    _controller.runJavaScriptReturningResult(_authPagePolishScript).then(
      (result) => AppLog.write(_tag, 'page polish: $result'),
      onError: (Object e) => AppLog.write(_tag, 'page polish failed: $e'),
    );
  }

  /// Always a fresh `loadRequest`, never `reload()`: the caller is telling us
  /// which page should be on screen, and the user may have wandered off it —
  /// reloading whatever they wandered onto is not what was asked for.
  Future<void> _goTo(Uri uri) async {
    // Logged before the load, not after: dochi bounces a signed-out webview
    // to /login, so `onPageFinished` alone can't tell you where the app
    // *meant* to go — every destination looks like the login page.
    AppLog.write(_tag, 'navigating to $uri');
    try {
      await _controller.loadRequest(uri);
    } catch (e) {
      AppLog.write(_tag, 'navigation to ${uri.path} failed: $e');
    }
  }

  /// Two fixes to dochi's own auth pages, applied in the app's webview only.
  ///
  /// Neither is a change to the website — this repo can't touch dochi's
  /// source, and both problems are specific to being hosted in a webview:
  ///
  /// 1. **A password reveal that works.** WebView2 draws Edge's native reveal
  ///    button (`::-ms-reveal`) inside every password field but never wires it
  ///    up — it is browser-shell UI, so clicking the eye does nothing at all.
  ///    WKWebView draws no reveal at all. Either way the field is unreadable,
  ///    so the native one is hidden and replaced.
  /// 2. **No "← 대시보드로" link.** In the app the webview *starts* at the
  ///    dashboard and is sent here by dochi because there is no session yet,
  ///    so the link only bounces back to this same page.
  ///
  /// Runs after the page has loaded, so after React has hydrated. Nothing is
  /// moved or removed from the DOM — the button is appended and the link is
  /// merely hidden — because re-parenting or deleting a node React is still
  /// tracking makes it throw and blank the whole page.
  static const String _authPagePolishScript = r'''
(() => {
  if (window.__tidePolish) return 'already applied';
  window.__tidePolish = true;

  var BRAND = '#444892';
  var MUTED = '#9ca3af';
  var EYE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"' +
    ' stroke="currentColor" stroke-width="2" stroke-linecap="round"' +
    ' stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8' +
    '-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>';

  var style = document.createElement('style');
  style.textContent = 'input::-ms-reveal{display:none!important;}';
  document.head.appendChild(style);

  function decorate(input) {
    if (input.dataset.tideReveal) return;
    var host = input.parentElement;
    if (!host) return;
    input.dataset.tideReveal = '1';
    host.style.position = 'relative';
    input.style.paddingRight = '2.5rem';

    var button = document.createElement('button');
    button.type = 'button';
    button.tabIndex = -1;
    button.setAttribute('aria-label', '누르고 있는 동안 비밀번호 보기');
    button.innerHTML = EYE;
    button.style.cssText = 'position:absolute;right:0.6rem;display:flex;' +
      'align-items:center;justify-content:center;width:1.5rem;height:1.5rem;' +
      'border:0;background:none;padding:0;color:' + MUTED + ';cursor:pointer;';

    // Measured off the input itself rather than pinned to the label's bottom
    // edge: the label also holds its caption text, so "bottom" is nowhere
    // near the middle of the field, and the button drifted as fonts loaded.
    function place() {
      button.style.top = (input.offsetTop + input.offsetHeight / 2) + 'px';
      button.style.transform = 'translateY(-50%)';
    }

    // Held, not toggled: the password is visible exactly as long as the
    // button is down, and hiding it again is releasing the mouse rather than
    // remembering to click a second time.
    function show(event) {
      // Keeps the caret where the user left it — without this the mousedown
      // pulls focus out of the field.
      if (event) event.preventDefault();
      input.type = 'text';
      button.style.color = BRAND;
    }
    function hide() {
      input.type = 'password';
      button.style.color = MUTED;
    }

    button.addEventListener('pointerdown', show);
    button.addEventListener('pointerup', hide);
    button.addEventListener('pointercancel', hide);
    button.addEventListener('pointerleave', hide);
    // The release can land anywhere if the pointer wandered off the button.
    window.addEventListener('pointerup', hide);
    window.addEventListener('blur', hide);

    host.appendChild(button);
    place();
    if (window.ResizeObserver) new ResizeObserver(place).observe(input);
  }

  function apply() {
    var reveals = 0, hidden = 0;
    var inputs = document.querySelectorAll('input[type=password]');
    for (var i = 0; i < inputs.length; i++) { decorate(inputs[i]); reveals++; }

    if (/^\/(login|signup|reset-password)/.test(location.pathname)) {
      var links = document.querySelectorAll('a[href^="/dashboard"]');
      for (var j = 0; j < links.length; j++) {
        links[j].style.display = 'none';
        hidden++;
      }
    }
    return 'reveals=' + reveals + ' hidden-links=' + hidden;
  }

  var first = apply();
  new MutationObserver(apply)
    .observe(document.body, {childList: true, subtree: true});
  return first;
})();
''';

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
