import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/capture_mode.dart';
import 'app_log.dart';
import 'capture_api_service.dart';
import 'storage_service.dart';

/// Result of a capture, once it has been (attempted to be) uploaded.
class CaptureResult {
  final AppCaptureMode mode;
  final CaptureUploadResult upload;

  const CaptureResult(this.mode, this.upload);
}

/// Captures a screen region and sends it to the Dochi capture API.
///
/// The capture is never kept on disk: it lives only long enough to be
/// uploaded, then the temp file is deleted (the product doesn't retain raw
/// captures — see `AGT-10` in the guideline doc).
class ScreenshotService {
  static const _tag = 'Capture';

  /// How long the Windows snip may take before we stop waiting for it. Long
  /// enough that framing a selection unhurried still lands, short enough that
  /// a *cancelled* snip can't sit around and adopt an unrelated image the
  /// user copies minutes later.
  static const _snipTimeout = Duration(seconds: 90);
  static const _snipPollInterval = Duration(milliseconds: 250);

  final _captureController = StreamController<CaptureResult>.broadcast();
  final CaptureApiService _apiService = CaptureApiService();

  /// Bumped on every `capture()`. A pending Windows snip whose generation is
  /// stale gives up: the user pressed the shortcut again, and only the newest
  /// selection should be claimed by the clipboard poll below.
  int _generation = 0;

  Stream<CaptureResult> get onCaptureProcessed => _captureController.stream;

  Future<CaptureResult?> capture(AppCaptureMode mode) async {
    final generation = ++_generation;
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'tide_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
    final targetPath = p.join(tempDir.path, fileName);
    AppLog.write(_tag, 'start mode=${mode.apiValue} path=$targetPath');

    final captured = Platform.isMacOS
        ? await _captureWithMacOSNative(targetPath)
        : await _captureWithSnippingTool(targetPath, generation);

    if (!captured) {
      AppLog.write(_tag, 'no image produced (cancelled, timed out or failed)');
      return null;
    }

    final file = File(targetPath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      AppLog.write(_tag, 'capture file missing or empty');
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      return null;
    }

    final capturedAt = file.statSync().modified;
    // No-op on Windows, where the capture already arrived via the clipboard.
    await StorageService.copyImageToClipboard(targetPath);

    AppLog.write(_tag, 'uploading ${file.lengthSync()} bytes');
    final upload = await _apiService.uploadCapture(
      image: file,
      mode: mode,
      capturedAt: capturedAt,
      timezone: await StorageService.localIanaTimeZone(),
    );
    AppLog.write(_tag, 'upload ${upload.status.name}: ${upload.notifications}');

    try {
      await file.delete();
    } catch (_) {}

    final result = CaptureResult(mode, upload);
    _captureController.add(result);
    return result;
  }

  /// Uses macOS built-in screencapture utility for interactive area selection.
  Future<bool> _captureWithMacOSNative(String outputPath) async {
    try {
      final result = await Process.run(
        '/usr/sbin/screencapture',
        ['-x', '-i', '-s', outputPath],
      );
      return result.exitCode == 0 && File(outputPath).existsSync();
    } catch (e) {
      AppLog.write(_tag, 'screencapture failed: $e');
      return false;
    }
  }

  /// The Windows path: open the Snipping Tool overlay and wait for its result
  /// to land on the clipboard.
  ///
  /// 🔑 Deliberately does *not* go through `screenCapturer.capture()`, which
  /// looks like it does exactly this but decides the snip is over by watching
  /// whether `SnippingTool.exe`/`ScreenClippingHost.exe` owns the foreground
  /// window — starting one second after launching it. The Snipping Tool
  /// regularly takes longer than that to come up cold, so the check sees "not
  /// clipping" immediately, reads the (still empty) clipboard and reports
  /// failure while the user is only just dragging their selection box. That
  /// is why captures used to end with the Snipping Tool's own toast and
  /// nothing from Tide.
  ///
  /// Waiting on the artifact instead of on a process name has no such race:
  /// the clipboard is cleared first, so anything that appears afterwards is
  /// this capture.
  Future<bool> _captureWithSnippingTool(String outputPath, int generation) async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (e) {
      AppLog.write(_tag, 'could not clear clipboard: $e');
    }

    // `ms-screenclip:` is the documented way to raise the overlay; there is no
    // API for it. `clippingMode=Rectangle` starts in rectangular selection.
    final opened = await launchUrl(
      Uri.parse('ms-screenclip://?clippingMode=Rectangle'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      AppLog.write(_tag, 'could not open the Snipping Tool overlay');
      return false;
    }

    final deadline = DateTime.now().add(_snipTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_snipPollInterval);
      if (generation != _generation) {
        AppLog.write(_tag, 'superseded by a newer capture');
        return false;
      }

      Uint8List? bytes;
      try {
        bytes = await screenCapturer.readImageFromClipboard();
      } catch (e) {
        // The clipboard is a shared, lockable resource: another process
        // holding it open makes a read fail transiently. Poll again.
        AppLog.write(_tag, 'clipboard read failed: $e');
        continue;
      }
      if (bytes == null || bytes.isEmpty) continue;

      await File(outputPath).writeAsBytes(bytes, flush: true);
      AppLog.write(_tag, 'snip landed on the clipboard (${bytes.length} bytes)');
      return true;
    }

    return false;
  }

  void dispose() {
    _captureController.close();
  }
}
