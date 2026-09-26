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
///
/// 🔑 The file is **capped**. It is not a private file in any meaningful
/// sense: it gets pasted into chats and attached to bug reports, and it
/// carries the titles of the tasks a capture produced. Left unbounded it
/// accumulates that history for the life of the install — the copy on this
/// machine still held lines written by 1.3.0, auth codes included (those are
/// redacted since 1.6.0, but old lines keep whatever they were written with).
/// A cap turns "forever" into "recently", which is all a diagnostic trail is
/// ever read for.
class AppLog {
  static const _fileName = 'tide.log';

  /// Trim once past this, and keep [_keepBytes] of the tail. The gap between
  /// the two is what stops the trim running on every single write.
  static const _maxBytes = 1024 * 1024;
  static const _keepBytes = 512 * 1024;

  /// Where the trail is written — `%APPDATA%\Tide\Tide\tide.log` on Windows,
  /// `~/Library/Application Support/...` on macOS.
  static Future<File> file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Writes are chained rather than each fired off on its own: two appends in
  /// flight at once interleave *inside* a line, and a log that garbles itself
  /// exactly when things are busiest is worse than no log. The trim rides the
  /// same chain, so it can never run against a half-written line.
  static Future<void> _pending = Future<void>.value();

  /// Fire-and-forget: a failed write must never take the caller down with it.
  static void write(String tag, String message) {
    debugPrint('$tag: $message');
    final line = '${DateTime.now().toIso8601String()}  [$tag] $message\n';
    _pending = _pending.then((_) async {
      try {
        final target = await file();
        await _trimIfHuge(target);
        await target.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {}
    });
  }

  /// Drops the oldest lines once the file outgrows [_maxBytes].
  ///
  /// The tail is cut at a line boundary rather than at an exact byte offset —
  /// starting the file mid-line leaves a fragment that reads like a real
  /// entry with its timestamp missing. A file that somehow holds no newline
  /// at all is replaced outright rather than searched for one that isn't
  /// there.
  static Future<void> _trimIfHuge(File target) async {
    if (!await target.exists()) return;
    if (await target.length() <= _maxBytes) return;

    final bytes = await target.readAsBytes();
    var start = bytes.length - _keepBytes;
    const newline = 0x0a;
    while (start < bytes.length && bytes[start] != newline) {
      start++;
    }
    final kept = start < bytes.length
        ? bytes.sublist(start + 1)
        : const <int>[];

    // The marker goes first so the file still reads top-to-bottom in time
    // order, and whoever opens it knows the beginning is missing rather than
    // concluding the app only started running an hour ago.
    final marker =
        '${DateTime.now().toIso8601String()}  [Log] 이 줄 위의 오래된 기록은 잘렸습니다.\n';
    await target.writeAsString(marker, flush: true);
    await target.writeAsBytes(kept, mode: FileMode.append, flush: true);
  }
}
