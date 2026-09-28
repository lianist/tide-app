import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_session.dart';
import 'app_log.dart';
import 'dochi_config.dart';

/// Handed to `/auth/app/start` and must match byte-for-byte (`public/api.md`
/// §앱 로그인 in the dochi repo). The scheme is claimed per platform:
/// `macos/Runner/Info.plist` declares it statically, while Windows writes it
/// to the registry at runtime — see `UrlSchemeService`.
const String _redirectUri = 'dochi://auth/callback';

const String _sessionKey = 'dochi_session';

/// Drives the dochi 앱 로그인 flow (system browser → deep link → code
/// exchange) and is the single place that holds and refreshes the session
/// (`API-4`). See `public/api.md` in the dochi repo for the exact contract.
class AuthService {
  static const _storage = FlutterSecureStorage(
    // Keychain sharing needs a provisioning profile we don't have for local
    // dev builds. This keeps the plain (non-shared) login keychain instead,
    // which needs no entitlement.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  /// Loads the stored session, if any. Never throws — a missing platform
  /// channel (e.g. under `flutter test`) or corrupted storage just means
  /// "no session", mirroring `StorageService`'s pattern elsewhere.
  Future<AuthSession?> _loadSession() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null) return null;
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      log('failed to load session: $e');
      return null;
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  /// Whether a session is stored at all — decides the app's initial screen.
  /// Doesn't check expiry; [validAccessToken] refreshes lazily when needed.
  Future<bool> hasSession() async => await _loadSession() != null;

  /// The signed-in user's email, for display.
  Future<String?> currentUserEmail() async => (await _loadSession())?.userEmail;

  /// Clears the stored session. There's no server-side logout endpoint
  /// (`public/api.md`) — the already-issued access token keeps working for
  /// its remaining lifetime, which is exactly why the app must drop its own
  /// copy rather than expecting the server to invalidate it.
  Future<void> signOut() async {
    await _storage.delete(key: _sessionKey);
  }

  /// Runs the full 앱 로그인 flow: opens the system browser at
  /// `/auth/app/start`, waits for the `dochi://auth/callback` deep link,
  /// then exchanges the code for a session. Returns null on success, or a
  /// message to show the user.
  Future<String?> signIn() async {
    final state = _randomState();
    final startUri = Uri.parse('$tideBaseUrl/auth/app/start').replace(
      queryParameters: {'redirect_uri': _redirectUri, 'state': state},
    );

    log('opening browser: $startUri');
    final opened = await launchUrl(startUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      return '브라우저를 열지 못했습니다.';
    }

    final Uri callback;
    try {
      callback = await AppLinks()
          .uriLinkStream
          .map(_logIncomingLink)
          .firstWhere(_isAuthCallback)
          .timeout(const Duration(minutes: 5));
    } on TimeoutException {
      return '로그인이 시간 초과되었습니다. 다시 시도해 주세요.';
    }

    final returnedState = callback.queryParameters['state'];
    if (returnedState != null && returnedState != state) {
      return '로그인 요청이 일치하지 않습니다. 다시 시도해 주세요.';
    }

    log('callback matched, state ok, code present — exchanging');
    final code = callback.queryParameters['code'];
    if (code == null) {
      return '로그인에 실패했습니다. 다시 시도해 주세요.';
    }

    return _exchangeToken({'grantType': 'code', 'code': code});
  }

  /// Deep links that arrive but don't match are the hard failure mode here:
  /// `firstWhere` simply never completes, so sign-in hangs on the spinner for
  /// the full five minutes with nothing shown. Logging every link makes that
  /// case visible instead.
  static Uri _logIncomingLink(Uri uri) {
    // 🔑 The `code` is redacted. It is a single-use credential, and a log
    // file gets pasted into chats and bug reports — the one place a
    // credential should never travel. Everything that makes the log useful
    // (did a link arrive, did it match, did the state come back) survives.
    final redacted = uri.queryParameters.containsKey('code')
        ? uri.replace(queryParameters: {
            ...uri.queryParameters,
            'code': '<redacted>',
          })
        : uri;
    log('deep link received: $redacted (matches=${_isAuthCallback(uri)})');
    return uri;
  }

  /// Sign-in leaves a trail in the shared log — the flow can't be reproduced
  /// without a real browser, so what actually came back is all there is to
  /// debug with. See [AppLog].
  static void log(String message) => AppLog.write('Auth', message);

  /// Matches the callback tolerantly. Browsers and OAuth providers normalise
  /// `/callback` to `/callback/` freely, and an exact `==` comparison against
  /// the path silently never matches when they do.
  static bool _isAuthCallback(Uri uri) {
    if (uri.scheme != 'dochi' || uri.host != 'auth') return false;
    final path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return path == '/callback';
  }

  /// Returns a usable access token, refreshing first if the stored one is
  /// expired (or about to be). Null means "not signed in" — the caller
  /// should treat that like a signed-out state.
  Future<String?> validAccessToken() async {
    final session = await _loadSession();
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;
    return refreshAccessToken();
  }

  /// Forces a refresh regardless of the locally cached expiry — for the
  /// "server itself returned 401" case (`public/api.md` §인증: "401을 받으면
  /// 갱신을 한 번 시도하고, 그것도 실패하면 로그인 화면을 띄운다"), where the
  /// token looked valid locally but the server disagrees. Null means the
  /// refresh failed and the session has been dropped.
  Future<String?> refreshAccessToken() async {
    final session = await _loadSession();
    if (session == null) return null;

    final error = await _exchangeToken({
      'grantType': 'refreshToken',
      'refreshToken': session.refreshToken,
    });
    if (error != null) {
      // A rejected refresh means the whole session is gone.
      log('refresh rejected — dropping the stored session: $error');
      await signOut();
      return null;
    }
    return (await _loadSession())?.accessToken;
  }

  /// `POST /auth/app/token` — code exchange and refresh share this one
  /// endpoint (`public/api.md`). Returns null on success, else an error
  /// message.
  Future<String?> _exchangeToken(Map<String, String> body) async {
    try {
      final response = await http.post(
        Uri.parse('$tideBaseUrl/auth/app/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final error = json['error'] as Map<String, dynamic>?;
        // Code and message only — the request and response both carry tokens.
        log('token exchange (${body['grantType']}) failed: '
            '${response.statusCode} ${error?['code']}');
        final message = error?['message'] as String?;
        return message ?? '로그인에 실패했습니다.';
      }

      final session = AuthSession.fromTokenResponse(json['data'] as Map<String, dynamic>);
      await _saveSession(session);
      return null;
    } catch (e) {
      log('token exchange (${body['grantType']}) failed: $e');
      return '네트워크 오류로 로그인하지 못했습니다.';
    }
  }

  String _randomState() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
