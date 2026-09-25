import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'models/capture_mode.dart';
import 'models/hotkey_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_log.dart';
import 'services/auth_service.dart';
import 'services/capture_api_service.dart';
import 'services/dashboard_navigation.dart';
import 'services/dochi_config.dart';
import 'services/hotkey_service.dart';
import 'services/notification_service.dart';
import 'services/screenshot_service.dart';
import 'services/tray_service.dart';
import 'services/url_scheme_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();
  await NotificationService.initialize(onTap: _openCaptureInHistory);
  await windowManager.ensureInitialized();
  await _configureWindow();
  UrlSchemeService.register();

  final isLoggedIn = await AuthService().hasSession();
  // First line of every run, so the log says which launch a later entry
  // belongs to — and says the log is working at all.
  //
  // 🔑 The version is in it because "the release doesn't have the fix" and
  // "you are running last week's build" look identical from the outside, and
  // telling them apart by hand cost a whole round trip once already. It comes
  // from the executable's own version resource, which Flutter fills in from
  // pubspec, so it cannot drift from what was actually built.
  final package = await PackageInfo.fromPlatform();
  AppLog.write('App', 'Tide ${package.version}+${package.buildNumber} '
      'started on ${Platform.operatingSystem}, signed in = $isLoggedIn');

  runApp(TtabongApp(initialIsLoggedIn: isLoggedIn));
}

/// Clicking a capture notification opens the agent run behind it.
///
/// The window is raised first because the notification may well be the only
/// part of the app the user can see — it keeps running with its window closed
/// so the global shortcuts stay registered.
Future<void> _openCaptureInHistory(String jobLogId) async {
  DashboardNavigation.goTo(historyUri(jobLogId));
  await windowManager.show();
  await windowManager.focus();
}

/// Makes the close button hide the window rather than end the process: the
/// global capture shortcuts are registered on the process and die with it.
/// This is the Windows half of what `AppDelegate` does on macOS.
///
/// 🔑 **The window deliberately keeps its taskbar button and its place in
/// Alt+Tab** (2026-09-25). It used to be hidden from both — `skipTaskbar` —
/// on the reasoning that the tray icon replaced them, the way `LSUIElement`
/// removes the Dock icon on macOS. That reasoning doesn't survive contact
/// with Windows: the tray is where you find an app that is *closed*, not one
/// you are looking at, and a visible window that can't be switched back to
/// is simply lost behind whatever the user opens next. The tray icon stays —
/// it is still the only way back once the window is closed.
Future<void> _configureWindow() async {
  if (!Platform.isWindows) return;
  // Everything must go through waitUntilReadyToShow, which is not merely a
  // timing helper here: it is the only place window_manager's Windows plugin
  // creates the ITaskbarList3 instance that the taskbar calls dereference.
  // Reaching one of them without it crashes the process outright
  // (0xC0000005) rather than failing gracefully.
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(title: 'Tide'),
    () async {
      await windowManager.setPreventClose(true);
    },
  );
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

class _AppRootState extends State<AppRoot> with WindowListener {
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
    windowManager.addListener(this);

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

  /// Only fires on Windows, where `_configureWindow` set `preventClose`. The
  /// tray's "Quit Tide Completely" bypasses this via `windowManager.destroy()`.
  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
    // The payload is what makes the click land on this run rather than on the
    // dashboard in general (`_openCaptureInHistory`).
    for (final message in messages) {
      NotificationService.show(message, payload: result.upload.jobLogId);
    }
    // The task list the dashboard is showing was rendered before this
    // capture existed, and nothing in the webview knows that changed.
    if (result.upload.status == CaptureUploadStatus.success) {
      DashboardNavigation.refresh();
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
