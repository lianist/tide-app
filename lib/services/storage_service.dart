import 'dart:io';
import 'package:flutter/foundation.dart';

class StorageService {
  /// The IANA zone name (`Asia/Seoul`), not the abbreviation `DateTime.now()
  /// .timeZoneName` gives (`KST`) — the capture API requires the former and
  /// 400s on the latter (`public/api.md` §캡처). `/etc/localtime` is a
  /// symlink into `.../zoneinfo/<iana name>` on macOS, so this needs no new
  /// dependency, matching how the rest of this file shells out for
  /// macOS-specific info.
  static Future<String> localIanaTimeZone() async {
    if (Platform.isMacOS) {
      try {
        final result = await Process.run('readlink', ['/etc/localtime']);
        final path = (result.stdout as String).trim();
        final marker = 'zoneinfo/';
        final index = path.indexOf(marker);
        if (result.exitCode == 0 && index != -1) {
          return path.substring(index + marker.length);
        }
      } catch (e) {
        debugPrint('Error reading local timezone: $e');
      }
    }
    // The server normalizes to UTC regardless, so this only affects "today"/
    // relative-date parsing for users outside UTC on a platform we haven't
    // handled yet — better than a 400 on every capture.
    return 'UTC';
  }

  /// Copies image to macOS clipboard using osascript.
  static Future<bool> copyImageToClipboard(String filePath) async {
    if (!Platform.isMacOS) return false;
    try {
      final script =
          'set the clipboard to (read (POSIX file "$filePath") as {«class PNGf»})';
      final result = await Process.run('osascript', ['-e', script]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error copying image to clipboard: $e');
      return false;
    }
  }
}
