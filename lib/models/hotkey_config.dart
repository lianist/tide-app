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
  /// the ⌘/⌥/⌃ glyphs are a Mac convention and read as mojibake there.
  ///
  /// 🔑 Shift over a number is folded into the character that key actually
  /// produces: **`Ctrl !`, not `Ctrl ⇧ 1`**. Two caps instead of three, and
  /// it is what the user sees printed on the key they are being asked to
  /// press. (US layout, which is what Korean keyboards use for the number
  /// row; a layout where ⇧2 isn't `@` would need its own table.)
  String get shortcutDisplay {
    final buffer = StringBuffer();
    final isWindows = Platform.isWindows;
    if (modifiers.contains(HotKeyModifier.control)) {
      buffer.write(isWindows ? 'Ctrl ' : '⌃ ');
    }
    if (modifiers.contains(HotKeyModifier.alt)) {
      buffer.write(isWindows ? 'Alt ' : '⌥ ');
    }
    // On Windows the shifted face replaces both the ⇧ token and the digit.
    final shiftedFace =
        isWindows && modifiers.contains(HotKeyModifier.shift) ? _shiftedFace(key) : null;
    if (modifiers.contains(HotKeyModifier.shift) && shiftedFace == null) {
      buffer.write('⇧ ');
    }
    if (modifiers.contains(HotKeyModifier.meta)) {
      buffer.write(isWindows ? 'Win ' : '⌘ ');
    }

    buffer.write(shiftedFace ?? _formatKey(key));
    return buffer.toString().trim();
  }

  /// What the key prints when Shift is held. Only the digits the app actually
  /// binds are listed — there is no reason to carry a full layout table for
  /// two shortcuts.
  static String? _shiftedFace(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.digit1) return '!';
    if (key == PhysicalKeyboardKey.digit2) return '@';
    return null;
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
