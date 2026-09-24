import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS-level (Notification Center) pushes for capture results — needed
/// because the main window can now be closed while the app keeps running
/// for the global shortcuts (`AppDelegate.applicationShouldTerminateAfterLastWindowClosed`),
/// so an in-window SnackBar would go unseen.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 0;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _plugin.initialize(
      settings: const InitializationSettings(macOS: DarwinInitializationSettings()),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> show(String body, {String title = 'Tide'}) async {
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(macOS: DarwinNotificationDetails()),
    );
  }
}
