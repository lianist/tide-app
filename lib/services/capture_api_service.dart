import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/capture_mode.dart';
import 'app_log.dart';
import 'auth_service.dart';
import 'dochi_config.dart';

enum CaptureUploadStatus { success, notSignedIn, failed }

class CaptureUploadResult {
  final CaptureUploadStatus status;

  /// User-facing text to show — one per notification. `public/api.md` says
  /// to raise one per created task ("건마다 알림을 띄운다"); for
  /// `completed`/`failed` there's exactly one.
  final List<String> notifications;

  /// The agent run this capture produced, if the server got far enough to
  /// record one. It identifies the entry a notification click should open in
  /// the history page — see [historyPath]. Null for a request that never
  /// reached the agent (a timeout or a server error carries no id).
  final String? jobLogId;

  /// Why a [CaptureUploadStatus.failed] failed, for the log only. Null when
  /// the failure came with a message meant for the user (see [rejected]).
  final String? logDetail;

  const CaptureUploadResult(
    this.status, {
    this.notifications = const [],
    this.jobLogId,
    this.logDetail,
  });

  /// No usable session — either never signed in, or the session was dropped
  /// (e.g. a rejected token refresh). The caller should fall back to the
  /// login screen.
  factory CaptureUploadResult.notSignedIn() =>
      const CaptureUploadResult(CaptureUploadStatus.notSignedIn);

  /// The server refused the request and said why, in Korean written for the
  /// user (`public/api.md` §에러 코드 — `message`는 그대로 띄워도 되는 문구다).
  /// Shown verbatim, because the message is the only part that says what to
  /// do about it: `403 CONSENT_REQUIRED` asks the user to open the dashboard
  /// and accept the privacy policy, and "보내지 못했습니다" would throw that
  /// away.
  ///
  /// Deliberately not switched on `code` — new codes appear without notice,
  /// and this path has to carry every one of them.
  factory CaptureUploadResult.rejected(String message) =>
      CaptureUploadResult(CaptureUploadStatus.failed, notifications: [message]);

  /// Something broke on our side — no network, an unparseable body, an
  /// exception. [detail] is for the log; it is technical text in whatever
  /// language the runtime felt like, so it never becomes a notification and
  /// the caller falls back to its own wording.
  factory CaptureUploadResult.failed(String detail) =>
      CaptureUploadResult(CaptureUploadStatus.failed, logDetail: detail);

  factory CaptureUploadResult.success(List<String> notifications, {String? jobLogId}) =>
      CaptureUploadResult(
        CaptureUploadStatus.success,
        notifications: notifications,
        jobLogId: jobLogId,
      );
}

/// Sends a capture to the Dochi capture API (`API-3` in the guideline doc).
///
/// See `public/api.md` in the dochi repo for the contract this follows.
class CaptureApiService {
  static const _tag = 'CaptureApi';

  final AuthService _authService = AuthService();

  Future<CaptureUploadResult> uploadCapture({
    required File image,
    required AppCaptureMode mode,
    required DateTime capturedAt,
    required String timezone,
  }) async {
    var token = await _authService.validAccessToken();
    AppLog.write(_tag, 'token present = ${token != null}');
    if (token == null) {
      return CaptureUploadResult.notSignedIn();
    }

    try {
      var response = await _send(token: token, image: image, mode: mode, capturedAt: capturedAt, timezone: timezone);
      AppLog.write(_tag, 'response ${response.statusCode}');

      // §인증: 401을 받으면 갱신을 한 번 시도하고, 그것도 실패하면 로그인 화면을 띄운다.
      if (response.statusCode == 401) {
        token = await _authService.refreshAccessToken();
        if (token == null) {
          return CaptureUploadResult.notSignedIn();
        }
        response = await _send(token: token, image: image, mode: mode, capturedAt: capturedAt, timezone: timezone);
        AppLog.write(_tag, 'retry response ${response.statusCode}');
      }

      final body = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'] as Map<String, dynamic>;
        return CaptureUploadResult.success(
          notificationsFor(data),
          jobLogId: data['jobLogId'] as String?,
        );
      }
      if (response.statusCode == 401) {
        return CaptureUploadResult.notSignedIn();
      }
      AppLog.write(_tag, 'failed body: $body');
      final message = (body['error'] as Map<String, dynamic>?)?['message'] as String?;
      return message != null
          ? CaptureUploadResult.rejected(message)
          : CaptureUploadResult.failed('Server returned ${response.statusCode}');
    } catch (e) {
      AppLog.write(_tag, 'upload failed: $e');
      return CaptureUploadResult.failed(e.toString());
    }
  }

  /// Builds the notification text(s) for a successful (`200`) capture.
  ///
  /// 🔴 Deliberately never branches on `failure.code` — `public/api.md`
  /// §변경 규칙 says new codes can appear without notice, and `message` is
  /// defined as human-readable Korean safe to show as-is. Switching on
  /// `code` here is exactly the trap the 2026-09-24 app-department notice
  /// warned about (an exhaustive `switch` with no default throws on an
  /// unknown value). `DUPLICATE_TASK`, announced on 2026-09-25, arrived and
  /// needed nothing here precisely because of that.
  @visibleForTesting
  static List<String> notificationsFor(Map<String, dynamic> data) {
    final messages = <String>[];

    for (final task in data['created'] as List<dynamic>? ?? const []) {
      messages.add('"${(task as Map<String, dynamic>)['title']}" 추가했어요.');
    }

    final completed = data['completed'] as Map<String, dynamic>?;
    if (completed != null) {
      messages.add('"${completed['title']}" 완료했어요.');
    }

    // The all-duplicates case arrives here as an ordinary `failed` outcome,
    // so its own `message` (which already names the existing task) covers it.
    final failure = data['failure'] as Map<String, dynamic>?;
    if (failure != null) {
      messages.add(failure['message'] as String? ?? '처리할 태스크를 찾지 못했어요.');
    }

    // What's left is the *partial* case: some tasks were created and others
    // were dropped for already existing. Without this the dropped ones vanish
    // silently, and the user is left wondering why one capture of three
    // things produced one notification.
    final duplicates = data['duplicates'] as List<dynamic>? ?? const [];
    if (duplicates.isNotEmpty && failure == null) {
      final first = (duplicates.first as Map<String, dynamic>)['title'];
      messages.add(duplicates.length == 1
          ? '"$first"은(는) 이미 있어요.'
          : '"$first" 외 ${duplicates.length - 1}건은 이미 있어요.');
    }

    return messages;
  }

  Future<http.StreamedResponse> _send({
    required String token,
    required File image,
    required AppCaptureMode mode,
    required DateTime capturedAt,
    required String timezone,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$tideBaseUrl/api/v1/captures'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['mode'] = mode.apiValue;
    // 🔑 UTC, not the local `DateTime`: `toIso8601String()` writes no offset
    // at all for a local time (`2026-09-25T18:00:00.000`), and api.md §시각
    // only promises to accept an ISO string *with* one. UTC renders a `Z`.
    request.fields['capturedAt'] = capturedAt.toUtc().toIso8601String();
    request.fields['timezone'] = timezone;
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      image.path,
      contentType: MediaType('image', 'png'),
    ));
    return request.send();
  }
}
