import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'models/capture_mode.dart';
import 'models/hotkey_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/capture_api_service.dart';
import 'services/hotkey_service.dart';
import 'services/screenshot_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();

  final isLoggedIn = await AuthService().hasSession();

  runApp(TtabongApp(initialIsLoggedIn: isLoggedIn));
}

class TtabongApp extends StatelessWidget {
  final bool initialIsLoggedIn;

  const TtabongApp({super.key, required this.initialIsLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ttabong',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AppRoot(initialIsLoggedIn: initialIsLoggedIn),
    );
  }
}

class AppRoot extends StatefulWidget {
  final bool initialIsLoggedIn;

  const AppRoot({super.key, required this.initialIsLoggedIn});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late bool _isLoggedIn;
  bool _isHotkeyActive = false;
  final _hotkeys = HotkeyConfig.defaultConfigs();
  late final ScreenshotService _screenshotService;
  late final HotkeyService _hotkeyService;
  StreamSubscription<CaptureResult>? _captureSubscription;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialIsLoggedIn;
    _screenshotService = ScreenshotService();

    // Global hotkeys stay registered regardless of which screen is showing.
    _hotkeyService = HotkeyService(
      configs: _hotkeys,
      onActionTriggered: (mode) => _screenshotService.capture(mode),
    );
    _hotkeyService.registerAll().then((_) {
      if (mounted) setState(() => _isHotkeyActive = _hotkeyService.isRegistered);
    });

    _captureSubscription =
        _screenshotService.onCaptureProcessed.listen(_showCaptureFeedback);
  }

  @override
  void dispose() {
    _captureSubscription?.cancel();
    _hotkeyService.unregisterAll();
    _screenshotService.dispose();
    super.dispose();
  }

  void _showCaptureFeedback(CaptureResult result) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final messages = switch (result.upload.status) {
      // Server-provided text — one per created task, or the single
      // completed/no-task-found message (`CaptureApiService._notificationsFor`).
      CaptureUploadStatus.success => result.upload.notifications,
      CaptureUploadStatus.notSignedIn =>
        ['${result.mode.displayName} captured, but you need to sign in first.'],
      CaptureUploadStatus.failed =>
        ['${result.mode.displayName} capture failed to send.'],
    };
    // `showSnackBar` queues automatically, so this naturally satisfies
    // api.md's "건마다 알림을 띄운다" for multiple created tasks.
    for (final message in messages) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
    // §인증: a refresh that fails mid-capture means the session is gone —
    // fall back to the login screen (a no-op if it was already showing).
    if (result.upload.status == CaptureUploadStatus.notSignedIn) {
      setState(() => _isLoggedIn = false);
    }
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(hotkeys: _hotkeys, onLoginSuccess: _handleLoginSuccess);
    }
    return DashboardScreen(isHotkeyActive: _isHotkeyActive);
  }
}
