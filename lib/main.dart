import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'models/capture_mode.dart';
import 'models/hotkey_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/capture_api_service.dart';
import 'services/hotkey_service.dart';
import 'services/notification_service.dart';
import 'services/screenshot_service.dart';
import 'services/tray_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();
  await NotificationService.initialize();
  await windowManager.ensureInitialized();
  // Required on Windows — the native window stays hidden until window_manager
  // is explicitly told to show it (windows/runner/flutter_window.cpp no
  // longer auto-shows on first frame, to avoid racing window_manager's own
  // visibility state). Harmless on macOS, where the window shows regardless
  // via the native AppDelegate/MainFlutterWindow path.
  const windowOptions = WindowOptions(size: Size(1280, 720), center: true, title: 'Tide');
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final isLoggedIn = await AuthService().hasSession();

  runApp(TtabongApp(initialIsLoggedIn: isLoggedIn));
}

class TtabongApp extends StatelessWidget {
  final bool initialIsLoggedIn;

  const TtabongApp({super.key, required this.initialIsLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tide',
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
  final _trayService = TrayService();
  StreamSubscription<CaptureResult>? _captureSubscription;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialIsLoggedIn;
    _screenshotService = ScreenshotService();
    _trayService.initialize();

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
    _trayService.dispose();
    super.dispose();
  }

  void _showCaptureFeedback(CaptureResult result) {
    final messages = switch (result.upload.status) {
      // Server-provided text — one per created task, or the single
      // completed/no-task-found message (`CaptureApiService._notificationsFor`).
      CaptureUploadStatus.success => result.upload.notifications,
      CaptureUploadStatus.notSignedIn =>
        ['${result.mode.displayName} captured, but you need to sign in first.'],
      CaptureUploadStatus.failed =>
        ['${result.mode.displayName} capture failed to send.'],
    };
    // OS notifications, not an in-window SnackBar — the window may be closed
    // (the app keeps running for the global shortcuts). One push per message
    // naturally satisfies api.md's "건마다 알림을 띄운다" for multiple created tasks.
    for (final message in messages) {
      NotificationService.show(message);
    }
    // §인증: a refresh that fails mid-capture means the session is gone —
    // fall back to the login screen next time the window is shown (a no-op
    // if it was already showing).
    if (result.upload.status == CaptureUploadStatus.notSignedIn && mounted) {
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
