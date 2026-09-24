import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttabong/models/capture_mode.dart';
import 'package:ttabong/services/capture_api_service.dart';

void main() {
  group('CaptureApiService Tests', () {
    test('uploadCapture returns notSignedIn when there is no stored session', () async {
      final service = CaptureApiService();
      final result = await service.uploadCapture(
        image: File('/tmp/does_not_matter.png'),
        mode: AppCaptureMode.createTask,
        capturedAt: DateTime.now(),
        timezone: 'UTC',
      );

      expect(result.status, CaptureUploadStatus.notSignedIn);
    });
  });
}
