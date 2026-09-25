import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS-level (Notification Center / Action Center) pushes for capture results
/// — needed because the main window can be closed while the app keeps running
/// for the global shortcuts, so an in-window SnackBar would go unseen.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 0;

  /// Identifies the app to the Windows Action Center. It must stay fixed:
  /// Windows keys a toast's history and the user's per-app notification
  /// settings off this pair, so changing either orphans both.
  static const _windowsAppUserModelId = 'com.dochi.tide';
  static const _windowsGuid = 'd59d1867-05bb-4ee9-941d-d1736b1546aa';

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _plugin.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Tide',
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsGuid,
        ),
      ),
    );
    // Windows has no runtime notification permission to request — toasts are
    // allowed by default and revoked only from system settings.
    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> show(String body, {String title = 'Tide'}) async {
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }
}
