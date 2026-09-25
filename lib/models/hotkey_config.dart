import 'dart:io';

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

  /// Rendered one token per space — `HotkeyBadge` splits on whitespace to draw
  /// a key cap per token.
  ///
  /// Windows names the modifiers it has names for (`Ctrl`, `Alt`, `Win`) —
  /// the ⌘/⌥/⌃ glyphs are a Mac convention and read as mojibake there. Shift
  /// is the exception: ⇧ is how Windows itself draws it (the touch keyboard,
  /// the Snipping Tool's shortcut hints), it's the one modifier glyph that
  /// isn't Mac-specific, and it keeps the badge row from being three wide
  /// word caps.
  String get shortcutDisplay {
    final buffer = StringBuffer();
    final isWindows = Platform.isWindows;
    if (modifiers.contains(HotKeyModifier.control)) {
      buffer.write(isWindows ? 'Ctrl ' : '⌃ ');
    }
    if (modifiers.contains(HotKeyModifier.alt)) {
      buffer.write(isWindows ? 'Alt ' : '⌥ ');
    }
    if (modifiers.contains(HotKeyModifier.shift)) {
      buffer.write('⇧ ');
    }
    if (modifiers.contains(HotKeyModifier.meta)) {
      buffer.write(isWindows ? 'Win ' : '⌘ ');
    }

    buffer.write(_formatKey(key));
    return buffer.toString().trim();
  }

  static String _formatKey(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.digit1) return '1';
    if (key == PhysicalKeyboardKey.digit2) return '2';
    return key.debugName?.replaceAll('Key ', '') ?? 'Key';
  }

  /// Default, fixed global shortcuts: ⇧⌘1 creates a task, ⇧⌘2 completes one,
  /// and Ctrl+Shift+1/2 on Windows. There is no UI to change these (see
  /// Non-goals in the guideline doc).
  ///
  /// Windows can't use the ⌘ equivalent: `meta` is the Windows key there, and
  /// `Win+Shift+<number>` is already claimed by the shell for launching a new
  /// instance of the Nth taskbar app. Ctrl is the conventional stand-in.
  static List<HotkeyConfig> defaultConfigs() {
    final primary =
        Platform.isWindows ? HotKeyModifier.control : HotKeyModifier.meta;
    return [
      HotkeyConfig(
        action: AppCaptureMode.createTask,
        key: PhysicalKeyboardKey.digit1,
        modifiers: [primary, HotKeyModifier.shift],
      ),
      HotkeyConfig(
        action: AppCaptureMode.completeTask,
        key: PhysicalKeyboardKey.digit2,
        modifiers: [primary, HotKeyModifier.shift],
      ),
    ];
  }
}
