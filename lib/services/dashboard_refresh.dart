import 'dart:async';

/// One-way nudge from "a capture just changed something on the server" to
/// "the dashboard webview is showing stale HTML".
///
/// The dashboard is a web page the app merely hosts, so a capture that
/// creates or completes a task server-side leaves the window showing the list
/// as it was before. Nothing in the webview knows to go and look again — that
/// is what this is for.
class DashboardRefresh {
  static final _controller = StreamController<void>.broadcast();

  /// Subscribed to by whichever platform dashboard view is on screen.
  static Stream<void> get onRequested => _controller.stream;

  static void request() => _controller.add(null);
}
