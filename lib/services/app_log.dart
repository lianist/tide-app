import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Append-only diagnostic trail, written to a file rather than stdout.
///
/// A Windows GUI build only has a console when it was launched from one, and
/// even then only if the runner redirects the streams — too many ways to end
/// up logging into the void while debugging the two flows (sign-in, capture)
/// that can't be reproduced without a browser and a human dragging a
/// selection box.
class AppLog {
  static const _fileName = 'tide.log';

  /// Where the trail is written — `%APPDATA%\com.example\ttabong\tide.log`
  /// on Windows, `~/Library/Application Support/...` on macOS.
  static Future<File> file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Writes are chained rather than each fired off on its own: two appends in
  /// flight at once interleave *inside* a line, and a log that garbles itself
  /// exactly when things are busiest is worse than no log.
  static Future<void> _pending = Future<void>.value();

  /// Fire-and-forget: a failed write must never take the caller down with it.
  static void write(String tag, String message) {
    debugPrint('$tag: $message');
    final line = '${DateTime.now().toIso8601String()}  [$tag] $message\n';
    _pending = _pending.then((_) async {
      try {
        final target = await file();
        await target.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {}
    });
  }
}
