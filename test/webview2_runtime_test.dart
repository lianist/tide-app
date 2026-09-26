import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tide/services/webview2_runtime.dart';

/// The WebView2 check decides whether the user sees the dashboard or a page
/// telling them to install a browser component. Both ways of getting it wrong
/// are bad in a way that is invisible from the machine running the test —
/// which already has the runtime — so the scan is exercised against
/// directories built here instead.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('wv2_test'));
  tearDown(() => root.deleteSync(recursive: true));

  Directory versionDir(String name) =>
      Directory(p.join(root.path, name))..createSync(recursive: true);

  test('finds a runtime when the executable is there', () {
    File(p.join(versionDir('153.0.4234.48').path, 'msedgewebview2.exe'))
        .writeAsStringSync('');

    expect(WebView2Runtime.hasRuntimeIn([root.path]), isTrue);
  });

  test('is not fooled by SetupMetrics, which outlives an uninstall', () {
    // Uninstalling the runtime empties the version folders but leaves this
    // one behind. Treating "the Application folder has a subdirectory" as
    // proof would answer yes on a machine with no runtime at all — and the
    // user would be back to a blank white dashboard with no explanation.
    versionDir('SetupMetrics');

    expect(WebView2Runtime.hasRuntimeIn([root.path]), isFalse);
  });

  test('a version folder without the executable does not count', () {
    versionDir('153.0.4234.48');

    expect(WebView2Runtime.hasRuntimeIn([root.path]), isFalse);
  });

  test('a root that does not exist is skipped, not an error', () {
    expect(
      WebView2Runtime.hasRuntimeIn([p.join(root.path, 'nope')]),
      isFalse,
    );
  });

  test('one root having it is enough', () {
    final second = Directory(p.join(root.path, 'second'))..createSync();
    File(p.join((Directory(p.join(second.path, '153.0.0.1'))..createSync()).path,
            'msedgewebview2.exe'))
        .writeAsStringSync('');

    expect(
      WebView2Runtime.hasRuntimeIn([p.join(root.path, 'missing'), second.path]),
      isTrue,
    );
  });
}
