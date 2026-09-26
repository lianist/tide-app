import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_log.dart';
import 'auth_service.dart';
import 'dochi_config.dart';

/// Hands the app's sign-in to the dashboard webview.
///
/// 🔑 The app has **two** sessions, not one: the app's own tokens
/// (`/auth/app/token`) and the webview's cookies. Nothing connected them, so
/// a user who had just signed in to the app still met a web login screen
/// inside it — and on macOS that screen could not be completed at all,
/// because Google refuses to authenticate in an embedded webview and the
/// flow had to be handed to the system browser, where the verification
/// cookie the webview had just set did not exist. The first attempt always
/// failed; the second signed in *the browser*, never the webview.
///
/// `POST /api/v1/web-session` closes that gap: the app trades its token for a
/// one-time URL that signs the webview in and lands on whatever path was
/// asked for. Nobody sees a web login screen, and the macOS dead end stops
/// existing because the webview never starts a Google sign-in.
class WebSessionService {
  static const _tag = 'WebSession';

  final AuthService _authService = AuthService();

  /// A one-time URL that signs the webview in and lands on [next].
  ///
  /// Null means "carry on without it" — no session, or the server could not
  /// mint one. The caller should fall back to opening the path directly and
  /// letting the web login screen do its job.
  ///
  /// 🔑 The URL is single-use and expires in an hour, so it is never stored
  /// and never logged (`public/api.md`: 주소를 로그에 남기지 않는다). Opening a
  /// used one lands on "링크가 만료되었거나 이미 사용되었습니다".
  Future<Uri?> signedInUrl({String next = dashboardPath}) async {
    final token = await _authService.validAccessToken();
    if (token == null) {
      AppLog.write(_tag, 'no session — skipping bridge for $next');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$tideBaseUrl/api/v1/web-session'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'next': next}),
      );

      if (response.statusCode != 200) {
        // 500 is documented as "leave the webview alone, the web login screen
        // will stand in", and 401 has already been through one refresh inside
        // validAccessToken. Neither is worth a retry here.
        AppLog.write(_tag, 'bridge unavailable (${response.statusCode}) for $next');
        return null;
      }

      final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
      final url = (data as Map<String, dynamic>?)?['url'] as String?;
      if (url == null) {
        AppLog.write(_tag, 'response carried no url');
        return null;
      }
      // Logged by destination only — the URL itself is a credential.
      AppLog.write(_tag, 'bridged to $next');
      return Uri.tryParse(url);
    } catch (e) {
      AppLog.write(_tag, 'bridge failed for $next: $e');
      return null;
    }
  }
}
