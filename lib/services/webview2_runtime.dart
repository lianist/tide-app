import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Is the Microsoft Edge WebView2 Runtime installed on this machine?
///
/// 🔑 The entire dashboard is a WebView2 — sidebar, task list, settings. The
/// runtime is a shared Windows component, not something the installer ships:
/// Microsoft distributes it Evergreen so it patches itself, and bundling a
/// private copy would add ~150 MB and make us responsible for its security
/// updates. Windows 11 always has it and Windows 10 has had it pushed through
/// Windows Update since 2021, so in practice it is there.
///
/// When it is *not* there, the dashboard is a blank white rectangle with no
/// explanation — indistinguishable, from the user's side, from a broken app,
/// a dead network or a failed login. This class exists so that case can be
/// named out loud instead. A clean old Windows 10 image is exactly the shape
/// of machine a store reviewer runs.
class WebView2Runtime {
  /// Where the Evergreen Runtime lands. Per-machine installs go under the
  /// 32-bit Program Files even on x64 (the runtime's own installer decides
  /// this, not us); the per-user variant goes to LOCALAPPDATA.
  static List<String> get _searchRoots => [
        Platform.environment['ProgramFiles(x86)'],
        Platform.environment['ProgramFiles'],
        Platform.environment['LOCALAPPDATA'],
      ]
          .whereType<String>()
          .map((root) => p.join(root, 'Microsoft', 'EdgeWebView', 'Application'))
          .toList();

  /// The page that installs it. Handed to the system browser, never opened in
  /// a webview — there is no working webview to open it in.
  static final Uri downloadUrl =
      Uri.parse('https://developer.microsoft.com/microsoft-edge/webview2/');

  /// True when a runtime is present, and on every platform but Windows.
  ///
  /// Looks for the executable rather than just the version folder: the
  /// Application directory also holds a `SetupMetrics` folder that survives
  /// an uninstall, so "a subdirectory exists" answers yes to a machine that
  /// has no runtime left.
  ///
  /// Anything unreadable counts as present. A false negative is the worse
  /// error by far — it would put a "install this first" wall in front of
  /// someone whose dashboard works perfectly.
  static bool get isInstalled {
    if (!Platform.isWindows) return true;
    return hasRuntimeIn(_searchRoots);
  }

  /// The scan itself, separated from where to scan so it can be tested
  /// against a directory built by hand — the two ways it can be wrong
  /// (missing the exe, being fooled by `SetupMetrics`) are otherwise only
  /// reachable by uninstalling the runtime from the machine running the test.
  @visibleForTesting
  static bool hasRuntimeIn(List<String> roots) {
    try {
      for (final root in roots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final entry in dir.listSync().whereType<Directory>()) {
          if (File(p.join(entry.path, 'msedgewebview2.exe')).existsSync()) {
            return true;
          }
        }
      }
    } catch (_) {
      return true;
    }
    return false;
  }
}
