import 'dart:async';

import 'dochi_config.dart';

/// One-way nudge from "something outside the webview decided it should be
/// showing a different page" to the webview itself.
///
/// Carries a **path**, not a URL, because the webview no longer opens service
/// pages directly — it trades the path for a one-time signed-in URL through
/// [WebSessionService]. Passing a full URL here would skip that and drop the
/// user on a login screen.
class DashboardNavigation {
  static final _controller = StreamController<String>.broadcast();

  /// Subscribed to by the dashboard webview while it is on screen.
  static Stream<String> get onRequested => _controller.stream;

  /// Back to the task list — after a capture changed it.
  static void refresh() => _controller.add(dashboardPath);

  static void goTo(String path) => _controller.add(path);
}
