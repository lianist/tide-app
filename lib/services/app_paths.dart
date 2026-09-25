import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the app puts things that belong next to the user, not next to the
/// executable.
class AppPaths {
  /// The browser profile WebView2 keeps for the dashboard — cookies, cache,
  /// and the dochi web session.
  ///
  /// 🔑 Explicit, because the default is a folder created *beside the
  /// executable*, and that is only writable by accident:
  ///   * under `Program Files` it isn't, which is why the installer puts the
  ///     app in `%LOCALAPPDATA%\Programs` instead;
  ///   * in an MSIX package the install folder is read-only by design, so the
  ///     default would fail there too — and a blank dashboard is exactly how
  ///     that failure shows up;
  ///   * and a profile living inside the install folder is deleted by the
  ///     next installer that cleans it, signing the user out for no reason.
  ///
  /// Local app data, not roaming: this is a browser cache, and it should not
  /// follow a roaming profile around.
  static String get webViewDataFolder {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      return p.join(local, 'Tide', 'WebView2');
    }
    // No LOCALAPPDATA at all is not a case worth inventing a fallback for —
    // the temp directory keeps the app working, minus session persistence.
    return p.join(Directory.systemTemp.path, 'Tide', 'WebView2');
  }
}
