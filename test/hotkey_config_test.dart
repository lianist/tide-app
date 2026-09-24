import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:ttabong/models/capture_mode.dart';
import 'package:ttabong/models/hotkey_config.dart';

void main() {
  group('HotkeyConfig Tests', () {
    test('Default configs contain exactly the create and complete shortcuts',
        () {
      final defaults = HotkeyConfig.defaultConfigs();
      expect(defaults.length, 2);

      final modes = defaults.map((d) => d.action).toList();
      expect(modes, contains(AppCaptureMode.createTask));
      expect(modes, contains(AppCaptureMode.completeTask));
    });

    test('Default shortcuts are ⇧⌘1 (create) and ⇧⌘2 (complete)', () {
      final defaults = HotkeyConfig.defaultConfigs();
      final createConfig =
          defaults.firstWhere((c) => c.action == AppCaptureMode.createTask);
      final completeConfig =
          defaults.firstWhere((c) => c.action == AppCaptureMode.completeTask);

      expect(createConfig.shortcutDisplay, '⇧ ⌘ 1');
      expect(completeConfig.shortcutDisplay, '⇧ ⌘ 2');
    });

    test('toHotKey converts accurately to hotkey_manager HotKey', () {
      const config = HotkeyConfig(
        action: AppCaptureMode.createTask,
        key: PhysicalKeyboardKey.digit1,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      );

      final hotKey = config.toHotKey();
      expect(hotKey.key, PhysicalKeyboardKey.digit1);
      expect(hotKey.modifiers, contains(HotKeyModifier.meta));
      expect(hotKey.modifiers, contains(HotKeyModifier.shift));
      expect(hotKey.scope, HotKeyScope.system);
    });
  });
}
