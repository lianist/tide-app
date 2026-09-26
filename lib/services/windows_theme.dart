import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import 'app_log.dart';

/// Is Windows drawing its own surfaces light or dark right now?
///
/// Only one thing needs this: the mark beside the app name in a toast sits on
/// the notification's chrome, which follows this setting. The near-white
/// reverse symbol disappears on a light toast, and the indigo one is muddy on
/// a dark one.
class WindowsTheme {
  static const _tag = 'Theme';
  static const _key =
      r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';

  /// 🔑 **System**, not Apps. Windows splits the setting in two — "Windows
  /// mode" paints the taskbar, the Action Center and toasts; "App mode"
  /// paints app windows. A toast is the first of those.
  static const _valueName = 'SystemUsesLightTheme';

  /// True when toasts are being drawn light.
  ///
  /// Defaults to true when the value can't be read, and that default is the
  /// safe one rather than the common one: the light-background symbol is an
  /// indigo circle, which is legible on *either* background, while the
  /// reverse symbol is only legible on a dark one. Guessing wrong in this
  /// direction is a slightly dull icon; guessing wrong the other way is an
  /// invisible one.
  static bool get isLight {
    if (!Platform.isWindows) return true;
    RegistryKey? key;
    try {
      key = Registry.openPath(RegistryHive.currentUser, path: _key);
      final value = key.getIntValue(_valueName);
      return value == null || value != 0;
    } catch (e) {
      AppLog.write(_tag, 'could not read the Windows theme: $e');
      return true;
    } finally {
      key?.close();
    }
  }
}
