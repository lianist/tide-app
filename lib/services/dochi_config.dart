/// Single place the app points at the Dochi deployment — shared by the
/// capture and auth API clients and by every page the webview opens. See
/// `public/api.md` in the dochi repo.
const String dochiBaseUrl = 'https://dochi-six.vercel.app';

/// The dashboard the webview loads at startup, and goes back to after a
/// capture changes something.
final Uri dashboardUri = Uri.parse('$dochiBaseUrl/dashboard');

/// The history page, scrolled to one agent run — where a capture
/// notification goes when it is clicked.
///
/// `jobLogId` comes straight off the capture response. A stale, foreign or
/// malformed id is not an error case to guard against: dochi answers all
/// three with a plain unhighlighted history list rather than an error page,
/// so an old notification still lands somewhere useful.
Uri historyUri(String jobLogId) =>
    Uri.parse('$dochiBaseUrl/history').replace(queryParameters: {'log': jobLogId});
