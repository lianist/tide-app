import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/capture_api_service.dart';

/// Covers the shapes `POST /api/v1/captures` can answer with, including the
/// ones announced in the 2026-09-25 app-department notice (`DUPLICATE_TASK`
/// and `duplicates[]`).
///
/// 🔴 The point of the last three cases is that an unknown `failure.code`
/// must come out as its server-written `message`, never as a branch. api.md
/// §변경 규칙 says new codes land without warning, so a test that pins the
/// *codes* would be the bug, not the guard.
void main() {
  group('notificationsFor', () {
    test('one notification per created task', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'created',
          'created': [
            {'id': 'a', 'title': '제안서 초안 보내기'},
            {'id': 'b', 'title': '회의실 예약'},
          ],
          'completed': null,
          'failure': null,
        }),
        ['"제안서 초안 보내기" 추가했어요.', '"회의실 예약" 추가했어요.'],
      );
    });

    test('completion names the task it closed', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'completed',
          'created': [],
          'completed': {'id': 'a', 'title': '보고서 제출하기'},
          'failure': null,
        }),
        ['"보고서 제출하기" 완료했어요.'],
      );
    });

    test('a failure shows the server message verbatim', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'failed',
          'created': [],
          'completed': null,
          'failure': {'code': 'NO_TASK_TO_CREATE', 'message': '생성할 태스크가 없어요.'},
        }),
        ['생성할 태스크가 없어요.'],
      );
    });

    test('every task already existing is just another failure message', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'failed',
          'created': [],
          'completed': null,
          'duplicates': [
            {'id': 'a', 'title': '보고서 제출하기'},
          ],
          'failure': {
            'code': 'DUPLICATE_TASK',
            'message': '이미 있는 태스크예요: 보고서 제출하기',
          },
        }),
        ['이미 있는 태스크예요: 보고서 제출하기'],
      );
    });

    test('a failure code nobody has heard of still shows its message', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'failed',
          'created': [],
          'completed': null,
          'failure': {'code': 'SOMETHING_INVENTED_NEXT_QUARTER', 'message': '아직 모르는 사유'},
        }),
        ['아직 모르는 사유'],
      );
    });

    test('partly-duplicate captures report both halves', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'created',
          'created': [
            {'id': 'a', 'title': '회의실 예약'},
          ],
          'completed': null,
          'duplicates': [
            {'id': 'b', 'title': '보고서 제출하기'},
            {'id': 'c', 'title': '제안서 초안 보내기'},
          ],
          'failure': null,
        }),
        [
          '"회의실 예약" 추가했어요.',
          '"보고서 제출하기" 외 1건은 이미 있어요.',
        ],
      );
    });

    test('an empty duplicates array adds nothing', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'created',
          'created': [
            {'id': 'a', 'title': '회의실 예약'},
          ],
          'completed': null,
          'duplicates': [],
          'failure': null,
        }),
        ['"회의실 예약" 추가했어요.'],
      );
    });

    test('a response without the new fields at all still works', () {
      expect(
        CaptureApiService.notificationsFor({
          'outcome': 'created',
          'created': [
            {'id': 'a', 'title': '회의실 예약'},
          ],
        }),
        ['"회의실 예약" 추가했어요.'],
      );
    });
  });
}
