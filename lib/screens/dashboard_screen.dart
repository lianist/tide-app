import 'dart:io';

import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_view.dart';

/// Full-window webview that hosts the dashboard (per the guideline doc,
/// the dashboard *is* a web/webview page — there's no separate native UI
/// to build here).
class DashboardScreen extends StatelessWidget {
  final bool isHotkeyActive;

  /// Passed straight through to [DashboardView] — the user signed out inside
  /// the dashboard web page, and the app has to drop its own session too.
  final VoidCallback onSignedOut;

  const DashboardScreen({
    super.key,
    required this.isHotkeyActive,
    required this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!isHotkeyActive) _buildPermissionBanner(),
            Expanded(child: DashboardView(onSignedOut: onSignedOut)),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    // Failure means different things per platform. macOS refuses to register
    // system-scope hotkeys without Accessibility, and can be sent straight to
    // the right settings pane. Windows has no such permission — registration
    // there fails because another process already owns the combination, which
    // no settings screen will fix.
    final isMacOS = Platform.isMacOS;
    final message = isMacOS
        ? 'Global shortcuts need Accessibility permission to work.'
        : 'Global shortcuts are unavailable — another app may already use them.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentAmber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppTheme.accentAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.darkTextPrimary),
            ),
          ),
          if (isMacOS)
            TextButton(
              onPressed: PermissionService.openAccessibilitySettings,
              child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
