import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';

/// Makes `dochi://auth/callback` resolve to this app on Windows.
///
/// macOS declares the scheme statically in `Runner/Info.plist`
/// (`CFBundleURLTypes`) and the OS picks it up when the bundle is installed.
/// Windows has no such manifest: the association lives in the registry and has
/// to be written at runtime, because it must name the absolute path of the
/// executable, which isn't known until the app is on the user's machine.
class UrlSchemeService {
  /// Must match `_redirectUri` in `AuthService` and the scheme dochi is
  /// configured to redirect to (`public/api.md` §앱 로그인).
  static const _scheme = 'dochi';

  /// Re-registered on every launch rather than once, so moving or reinstalling
  /// the executable can't leave the association pointing at a path that no
  /// longer exists. Writes under HKCU, so it needs no elevation.
  static void register() {
    if (!Platform.isWindows) return;

    RegistryKey? schemeKey;
    RegistryKey? commandKey;
    try {
      schemeKey = Registry.currentUser.createKey('Software\\Classes\\$_scheme');
      // An empty-named "URL Protocol" value is the flag that marks a key as a
      // protocol handler; its content is irrelevant, its presence is not.
      schemeKey.createValue(const RegistryValue.string('URL Protocol', ''));
      schemeKey.createValue(const RegistryValue.string('', 'URL:Tide Protocol'));

      commandKey = schemeKey.createKey('shell\\open\\command');
      commandKey.createValue(
        RegistryValue.string('', '"${Platform.resolvedExecutable}" "%1"'),
      );
    } catch (e) {
      // Losing the association costs the user the in-app login round trip,
      // which is worth a degraded start rather than a failed one.
      debugPrint('UrlSchemeService: failed to register $_scheme scheme: $e');
    } finally {
      commandKey?.close();
      schemeKey?.close();
    }
  }
}
