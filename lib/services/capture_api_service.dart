import 'dart:convert';
import 'dart:io';
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

  const CaptureUploadResult(this.status, {this.notifications = const []});

  /// No usable session — either never signed in, or the session was dropped
  /// (e.g. a rejected token refresh). The caller should fall back to the
  /// login screen.
  factory CaptureUploadResult.notSignedIn() =>
      const CaptureUploadResult(CaptureUploadStatus.notSignedIn);

  factory CaptureUploadResult.failed(String detail) =>
      CaptureUploadResult(CaptureUploadStatus.failed, notifications: [detail]);

  factory CaptureUploadResult.success(List<String> notifications) =>
      CaptureUploadResult(CaptureUploadStatus.success, notifications: notifications);
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
        return CaptureUploadResult.success(_notificationsFor(body['data'] as Map<String, dynamic>));
      }
      if (response.statusCode == 401) {
        return CaptureUploadResult.notSignedIn();
      }
      AppLog.write(_tag, 'failed body: $body');
      final message = (body['error'] as Map<String, dynamic>?)?['message'] as String?;
      return CaptureUploadResult.failed(message ?? 'Server returned ${response.statusCode}');
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
  /// unknown value).
  List<String> _notificationsFor(Map<String, dynamic> data) {
    final created = data['created'] as List<dynamic>? ?? [];
    if (created.isNotEmpty) {
      return created.map((task) => '"${(task as Map<String, dynamic>)['title']}" added').toList();
    }
    final completed = data['completed'] as Map<String, dynamic>?;
    if (completed != null) {
      return ['Completed: "${completed['title']}"'];
    }
    final failure = data['failure'] as Map<String, dynamic>?;
    if (failure != null) {
      return [failure['message'] as String? ?? 'No task found.'];
    }
    return const [];
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
      Uri.parse('$dochiBaseUrl/api/v1/captures'),
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
