import 'dart:async';

import 'dochi_config.dart';

/// One-way channel from "something outside the webview decided it should be
/// showing a different page" to the webview itself.
///
/// Two things use it, for the same underlying reason — the dashboard is a web
/// page the app merely hosts, and nothing inside it knows what the app just
/// did:
///   * a capture created or completed a task, so the list on screen is stale;
///   * the user clicked a capture notification, which should land on that
///     run in the history page.
class DashboardNavigation {
  static final _controller = StreamController<Uri>.broadcast();

  /// Subscribed to by the dashboard webview while it is on screen.
  static Stream<Uri> get onRequested => _controller.stream;

  /// Back to the task list — after a capture changed it.
  static void refresh() => _controller.add(dashboardUri);

  static void goTo(Uri uri) => _controller.add(uri);
}
