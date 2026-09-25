import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class StorageService {
  /// The IANA zone name (`Asia/Seoul`), not the abbreviation `DateTime.now()
  /// .timeZoneName` gives (`KST`) — the capture API requires the former and
  /// 400s on the latter (`public/api.md` §캡처). macOS keeps reading
  /// `/etc/localtime`, which is a symlink into `.../zoneinfo/<iana name>`,
  /// so the behaviour that already ships there is unchanged.
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
    // Windows stores its own zone ids (`Korea Standard Time`), which the API
    // rejects, and the CLDR table mapping them to IANA names isn't something
    // worth vendoring here — so the plugin does it.
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      if (timezone.identifier.isNotEmpty) return timezone.identifier;
    } catch (e) {
      debugPrint('Error reading local timezone: $e');
    }
    // The server normalizes to UTC regardless, so this only affects "today"/
    // relative-date parsing for users outside UTC on a platform we haven't
    // handled yet — better than a 400 on every capture.
    return 'UTC';
  }

  /// Copies image to macOS clipboard using osascript.
  ///
  /// macOS only, deliberately. The Windows capture path never needs this: it
  /// drives the Snipping Tool over `ms-screenclip://` and takes the result
  /// *off* the clipboard (see `ScreenshotService`), so the image is already
  /// there by the time a capture completes. Shelling out again would also
  /// flash a console window, since `powershell` is a console binary and this
  /// is a GUI app.
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
