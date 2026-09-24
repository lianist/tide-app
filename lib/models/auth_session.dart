/// A signed-in Dochi session, as returned by `POST /auth/app/token`
/// (dochi repo's `public/api.md` §앱 로그인).
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String userEmail;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.userEmail,
  });

  /// A 30s margin so a refresh started right before expiry doesn't lose the
  /// race against the request it's meant to authorize.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  factory AuthSession.fromTokenResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      userId: user['id'] as String,
      userEmail: user['email'] as String,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        userId: json['userId'] as String,
        userEmail: json['userEmail'] as String,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'userId': userId,
        'userEmail': userEmail,
      };
}
