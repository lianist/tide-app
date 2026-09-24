import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';

const String _dashboardUrl = 'https://dochi-six.vercel.app/dashboard';

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
      ..loadRequest(Uri.parse(_dashboardUrl));
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
