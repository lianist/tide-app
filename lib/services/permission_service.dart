import 'dart:io';
import 'package:flutter/foundation.dart';

class PermissionService {
  static Future<void> openAccessibilitySettings() async {
    if (!Platform.isMacOS) return;
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
      ]);
    } catch (e) {
      debugPrint('Error opening Accessibility settings: $e');
    }
  }

  static Future<void> openScreenRecordingSettings() async {
    if (!Platform.isMacOS) return;
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
      ]);
    } catch (e) {
      debugPrint('Error opening Screen Recording settings: $e');
    }
  }

  /// Verifies if screencapture CLI is available on the machine.
  static Future<bool> isScreenCaptureAvailable() async {
    if (!Platform.isMacOS) return false;
    final screencaptureFile = File('/usr/sbin/screencapture');
    return screencaptureFile.existsSync();
  }
}
