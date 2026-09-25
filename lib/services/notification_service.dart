import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_log.dart';

/// OS-level (Notification Center / Action Center) pushes for capture results
/// — needed because the main window can be closed while the app keeps running
/// for the global shortcuts, so an in-window SnackBar would go unseen.
class NotificationService {
  static const _tag = 'Notification';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 0;
  static void Function(String payload)? _onTap;

  /// Identifies the app to the Windows Action Center. It must stay fixed:
  /// Windows keys a toast's history and the user's per-app notification
  /// settings off this pair, so changing either orphans both. (It was
  /// `com.dochi.tide` until 1.4.0, when the app's own identity was settled on
  /// Tide throughout — a rename worth doing exactly once, before anyone but
  /// the author had the app installed.)
  static const _windowsAppUserModelId = 'com.tide.app';
  static const _windowsGuid = 'd59d1867-05bb-4ee9-941d-d1736b1546aa';

  /// [onTap] is handed the payload of whichever notification was clicked —
  /// for captures, the id of the agent run behind it.
  static Future<void> initialize({void Function(String payload)? onTap}) async {
    if (_initialized) return;
    _initialized = true;
    _onTap = onTap;

    await _plugin.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Tide',
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsGuid,
        ),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );
    // Windows has no runtime notification permission to request — toasts are
    // allowed by default and revoked only from system settings.
    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    AppLog.write(_tag, 'clicked, payload=${payload ?? '(none)'}');
    if (payload == null || payload.isEmpty) return;
    _onTap?.call(payload);
  }

  static Future<void> show(
    String body, {
    String title = 'Tide',
    String? payload,
  }) async {
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }
}
