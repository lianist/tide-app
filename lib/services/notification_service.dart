import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

import 'app_log.dart';
import 'app_paths.dart';

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
      settings: InitializationSettings(
        macOS: const DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Tide',
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsGuid,
          // The mark beside the app name in the toast's header. Windows
          // reads it from this path — without it the header shows a blank
          // square on every capture result.
          iconPath: await _unpackWindowsIcon(),
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

  /// Writes the app icon out to a real file and returns its path.
  ///
  /// 🔑 Windows reads a toast's icon from disk — there is no way to hand it
  /// bytes — and Flutter assets live inside the bundle, which on Windows
  /// means a file the shell will not follow into. So it gets copied out.
  ///
  /// Rewritten on every launch rather than only when missing: the file is a
  /// copy of something that ships with the build, so a truncated or
  /// half-written one from a previous crash fixes itself, and an icon
  /// changed in a later version replaces the old one. It costs one small
  /// write at startup.
  ///
  /// Null on failure, which is what the setting takes to mean "no icon" —
  /// the same place we were before, and never a reason to lose the
  /// notification itself.
  static Future<String?> _unpackWindowsIcon() async {
    if (!Platform.isWindows) return null;
    try {
      final bytes = await rootBundle.load(_headerIconAsset);
      final file = File(AppPaths.notificationIconFile);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (e) {
      AppLog.write(_tag, 'could not unpack the toast icon: $e');
      return null;
    }
  }

  /// 🔑 A toast shows **two** Tide marks and they are not the same image.
  ///
  /// This is the small one beside the app name, and it is the plain symbol —
  /// an indigo circle — on every theme. The reverse symbol reads better on a
  /// dark toast, but it is a near-white circle that disappears entirely on a
  /// light one, and swapping between them by theme was more machinery than
  /// the difference was worth: the indigo circle is legible on both.
  ///
  /// 256px rather than a smaller size: Windows scales it by the display's
  /// scaling factor, and a 48px source blown up is visible.
  static const _headerIconAsset = 'assets/brand/tide-symbol-256.png';

  /// The large mark in the toast's body. The app icon proper, and the same
  /// one either way — it sits on the notification's content area, which is
  /// its own surface.
  static const _bodyLogoAsset = 'assets/app-icon/png/tide-app-icon-256.png';

  static void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    AppLog.write(_tag, 'clicked, payload=${payload ?? '(none)'}');
    if (payload == null || payload.isEmpty) return;
    _onTap?.call(payload);
  }

  /// The large Tide logo in the toast's body.
  ///
  /// Unlike the header mark, this one travels **with the notification**
  /// rather than with the app's shell registration, so it shows even where
  /// that registration is wrong or stale. Windows caches an app's registered
  /// icon aggressively; this does not go through that cache.
  static final WindowsImage? _toastLogo = _buildToastLogo();

  static WindowsImage? _buildToastLogo() {
    if (!Platform.isWindows) return null;
    try {
      final uri = _toastLogoUri();
      if (uri == null) return null;
      return WindowsImage(
        uri,
        altText: 'Tide',
        placement: WindowsImagePlacement.appLogoOverride,
      );
    } catch (e) {
      AppLog.write(_tag, 'no toast logo: $e');
      return null;
    }
  }

  /// Where the shell can read the mark from.
  ///
  /// The plugin's own helper picks the right scheme — `ms-appx:` inside an
  /// MSIX package, a file path outside one — but it builds that file path
  /// against the **working directory**, which is not the executable's folder
  /// when the app is started by a `dochi://` link or from a terminal. So the
  /// file case is rebuilt from [Platform.resolvedExecutable], and the helper
  /// is kept for the packaged case and as the fallback.
  static Uri? _toastLogoUri() {
    final fromPlugin = WindowsImage.getAssetUri(_bodyLogoAsset);
    if (fromPlugin.scheme != 'file') return fromPlugin;

    final beside = File(p.join(
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      _bodyLogoAsset,
    ));
    return beside.existsSync()
        ? Uri.file(beside.path, windows: true)
        : fromPlugin;
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
      notificationDetails: NotificationDetails(
        macOS: const DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(
          images: [?_toastLogo],
        ),
      ),
    );
  }
}
