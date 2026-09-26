import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/capture_api_service.dart';

/// A capture that the server refuses has to say *why* on screen.
///
/// This was wrong until 1.8.0: the message came back from the API correctly
/// and then main.dart replaced it with "캡처를 보내지 못했습니다." The case that
/// exposed it was `403 CONSENT_REQUIRED`, where the message is the only
/// thing that tells the user what to do — open the dashboard and accept the
/// privacy policy. Technical failures are the opposite case: their detail is
/// a Dart exception and must never reach a notification.
void main() {
  test('a refusal from the server is shown to the user', () {
    final result = CaptureUploadResult.rejected(
      '개인정보처리방침 동의가 필요합니다. Tide 대시보드를 열어 동의해 주세요.',
    );

    expect(result.status, CaptureUploadStatus.failed);
    expect(result.notifications, [
      '개인정보처리방침 동의가 필요합니다. Tide 대시보드를 열어 동의해 주세요.',
    ]);
    expect(result.logDetail, isNull);
  });

  test('a technical failure keeps its detail out of the notification', () {
    final result = CaptureUploadResult.failed(
      "ClientException with SocketException: Failed host lookup",
    );

    expect(result.status, CaptureUploadStatus.failed);
    // Empty is what makes the caller fall back to its own wording.
    expect(result.notifications, isEmpty);
    expect(result.logDetail, contains('SocketException'));
  });
}
