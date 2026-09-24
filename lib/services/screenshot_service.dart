import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';
import '../models/capture_mode.dart';
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
  final _captureController = StreamController<CaptureResult>.broadcast();
  final CaptureApiService _apiService = CaptureApiService();

  Stream<CaptureResult> get onCaptureProcessed => _captureController.stream;

  Future<CaptureResult?> capture(AppCaptureMode mode) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'ttabong_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
    final targetPath = p.join(tempDir.path, fileName);

    final captured = Platform.isMacOS
        ? await _captureWithMacOSNative(targetPath)
        : await _captureWithPlugin(targetPath);

    if (!captured) {
      debugPrint('Capture cancelled or failed.');
      return null;
    }

    final file = File(targetPath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      return null;
    }

    final capturedAt = file.statSync().modified;
    await StorageService.copyImageToClipboard(targetPath);

    final upload = await _apiService.uploadCapture(
      image: file,
      mode: mode,
      capturedAt: capturedAt,
      timezone: await StorageService.localIanaTimeZone(),
    );

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
      debugPrint('Error invoking screencapture: $e');
      return _captureWithPlugin(outputPath);
    }
  }

  /// Fallback using the screen_capturer package.
  Future<bool> _captureWithPlugin(String outputPath) async {
    try {
      final capturedData = await screenCapturer.capture(
        mode: CaptureMode.region,
        imagePath: outputPath,
        silent: true,
      );
      return capturedData != null && File(outputPath).existsSync();
    } catch (e) {
      debugPrint('Error with screen_capturer plugin: $e');
      return false;
    }
  }

  void dispose() {
    _captureController.close();
  }
}
