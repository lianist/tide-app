import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';

const String _dashboardUrl = 'https://dochi-six.vercel.app/dashboard';
final Uri _dashboardUri = Uri.parse(_dashboardUrl);

/// Full-window webview that hosts the dashboard (per the guideline doc,
/// the dashboard *is* a web/webview page — there's no separate native UI
/// to build here).
class DashboardScreen extends StatefulWidget {
  final bool isHotkeyActive;

  const DashboardScreen({
    super.key,
    required this.isHotkeyActive,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: _handleNavigation))
      ..loadRequest(_dashboardUri);
  }

  /// Google (and any other off-dochi-domain sign-in) refuses to run inside
  /// an embedded webview — it detects the WebView user agent and blocks the
  /// flow. Anything leaving dochi's own host opens in the system browser
  /// instead; same-host navigation (the dashboard itself, email/password
  /// login) stays in the webview.
  FutureOr<NavigationDecision> _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri != null && uri.host != _dashboardUri.host) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.isHotkeyActive) _buildPermissionBanner(),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentAmber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppTheme.accentAmber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Global shortcuts need Accessibility permission to work.',
              style: TextStyle(fontSize: 12, color: AppTheme.darkTextPrimary),
            ),
          ),
          TextButton(
            onPressed: PermissionService.openAccessibilitySettings,
            child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
