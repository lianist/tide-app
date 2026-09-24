import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'capture_mode.dart';

class HotkeyConfig {
  final AppCaptureMode action;
  final PhysicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;
  final bool isEnabled;

  const HotkeyConfig({
    required this.action,
    required this.key,
    required this.modifiers,
    this.isEnabled = true,
  });

  HotKey toHotKey() {
    return HotKey(
      key: key,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }

  String get shortcutDisplay {
    final buffer = StringBuffer();
    if (modifiers.contains(HotKeyModifier.control)) {
      buffer.write('⌃ ');
    }
    if (modifiers.contains(HotKeyModifier.alt)) {
      buffer.write('⌥ ');
    }
    if (modifiers.contains(HotKeyModifier.shift)) {
      buffer.write('⇧ ');
    }
    if (modifiers.contains(HotKeyModifier.meta)) {
      buffer.write('⌘ ');
    }

    buffer.write(_formatKey(key));
    return buffer.toString().trim();
  }

  static String _formatKey(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.digit1) return '1';
    if (key == PhysicalKeyboardKey.digit2) return '2';
    return key.debugName?.replaceAll('Key ', '') ?? 'Key';
  }

  /// Default, fixed global shortcuts: ⇧⌘1 creates a task, ⇧⌘2 completes one.
  /// There is no UI to change these (see Non-goals in the guideline doc).
  static List<HotkeyConfig> defaultConfigs() {
    return const [
      HotkeyConfig(
        action: AppCaptureMode.createTask,
        key: PhysicalKeyboardKey.digit1,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      ),
      HotkeyConfig(
        action: AppCaptureMode.completeTask,
        key: PhysicalKeyboardKey.digit2,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      ),
    ];
  }
}
