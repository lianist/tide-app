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

  /// What the badge shows. `HotkeyBadge` splits on whitespace and draws a key
  /// cap per token, so the number of tokens decides the look.
  ///
  /// 🔑 **One cap, one shape, both platforms** — `Ctrl+Shift+1` on Windows
  /// and `Shift+⌘+1` on macOS. Each keeps the symbol its own users know
  /// (`Ctrl` vs `⌘`), but the joining and the ordering match, so the two
  /// builds don't read like two different products.
  ///
  /// Windows survived two attempts at something shorter — `Ctrl ⇧ 1` and
  /// `Ctrl !` (the shifted face of the key). Both were more compact and both
  /// were harder to read at a glance, which is the only thing this line is
  /// for.
  ///
  /// The registered combination never changed through any of it; only the
  /// label moves.
  String get shortcutDisplay {
    final isWindows = Platform.isWindows;
    final parts = <String>[];
    if (modifiers.contains(HotKeyModifier.control)) {
      parts.add(isWindows ? 'Ctrl' : '⌃');
    }
    if (modifiers.contains(HotKeyModifier.alt)) {
      parts.add(isWindows ? 'Alt' : '⌥');
    }
    // 🔑 Shift is spelled out on both platforms. `⇧` is the correct Mac
    // glyph, but next to `⌘` it reads as decoration rather than a key name —
    // `Shift+⌘+1` is what a person can repeat out loud.
    if (modifiers.contains(HotKeyModifier.shift)) {
      parts.add('Shift');
    }
    if (modifiers.contains(HotKeyModifier.meta)) {
      parts.add(isWindows ? 'Win' : '⌘');
    }
    parts.add(_formatKey(key));
    return parts.join('+');
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
