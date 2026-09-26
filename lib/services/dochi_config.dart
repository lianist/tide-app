/// Single place the app points at the Tide service — shared by the capture and
/// auth API clients and by every page the webview opens.
///
/// The service answers on both `tide-task.vercel.app` and the older
/// `dochi-six.vercel.app`; they are the same server, not a redirect. The app
/// uses one of them for *everything* on purpose: web sign-in cookies are
/// per-host, so pointing the API at one host and the webview at the other
/// would sign the user in twice. `POST /api/v1/web-session` also builds its
/// one-time URL from the host that asked, which keeps that consistent.
const String tideBaseUrl = 'https://tide-task.vercel.app';

/// The deep link scheme stays `dochi://`. It is invisible to users, and
/// `public/api.md` requires the redirect URI to match byte for byte.
const String tideHost = 'tide-task.vercel.app';

/// Paths inside the service. They are paths rather than full URLs because the
/// webview does not open them directly any more — they are handed to
/// `POST /api/v1/web-session` as `next`, which returns the URL to actually
/// open. See [WebSessionService].
const String dashboardPath = '/dashboard';

/// One agent run in the history page — where a capture notification goes when
/// it is clicked.
///
/// A stale, foreign or malformed id is not a case to guard against: the
/// service answers all three with a plain unhighlighted history list rather
/// than an error page, so an old notification still lands somewhere useful.
String historyPath(String jobLogId) => '/history?log=$jobLogId';

/// Where the webview lands when its own session has expired. Seeing this is
/// the app's cue to ask for a fresh one-time URL.
const String loginPath = '/login';
