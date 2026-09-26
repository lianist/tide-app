import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/dochi_config.dart';

/// Telling "the user signed out" from "the web session expired" is a
/// one-character difference in a URL with opposite correct responses, so the
/// discrimination is pinned here rather than left to a reading of the widget.
///
/// Getting it backwards is worse than doing nothing: bridging after a
/// deliberate sign-out hands the webview a one-time URL that signs it back
/// into the account the user just left.
bool _isDeliberateSignOut(String url) {
  final uri = Uri.parse(url);
  return uri.host == tideHost &&
      uri.path == loginPath &&
      uri.queryParameters.containsKey(signedOutParam);
}

bool _isExpiredSession(String url) {
  final uri = Uri.parse(url);
  return uri.host == tideHost &&
      uri.path == loginPath &&
      !uri.queryParameters.containsKey(signedOutParam);
}

void main() {
  test('the sign-out marker is recognised', () {
    expect(_isDeliberateSignOut('$tideBaseUrl/login?signedOut=1'), isTrue);
  });

  test('a bare login page is an expired session, not a sign-out', () {
    expect(_isExpiredSession('$tideBaseUrl/login'), isTrue);
    expect(_isDeliberateSignOut('$tideBaseUrl/login'), isFalse);
  });

  test('the other login-page parameters are not mistaken for it', () {
    // api.md: `?next=…` and `?error=…` can appear on an expired session.
    for (final url in [
      '$tideBaseUrl/login?next=%2Fdashboard',
      '$tideBaseUrl/login?error=expired',
      '$tideBaseUrl/login?next=%2Fhistory&error=expired',
    ]) {
      expect(_isDeliberateSignOut(url), isFalse, reason: url);
      expect(_isExpiredSession(url), isTrue, reason: url);
    }
  });

  test('the marker still counts alongside other parameters', () {
    expect(
      _isDeliberateSignOut('$tideBaseUrl/login?next=%2Fdashboard&signedOut=1'),
      isTrue,
    );
  });

  test('neither applies away from the login page', () {
    expect(_isDeliberateSignOut('$tideBaseUrl/dashboard?signedOut=1'), isFalse);
    expect(_isExpiredSession('$tideBaseUrl/dashboard'), isFalse);
  });
}
