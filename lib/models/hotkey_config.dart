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
  /// 🔑 The two platforms want different things here:
  ///   * **Windows spells the whole chord inside one cap** — `Ctrl+Shift+1`.
  ///     It is how Windows itself writes shortcuts, and it survived two
  ///     attempts at something shorter: `Ctrl ⇧ 1` (2026-09-25) and `Ctrl !`
  ///     (the shifted face of the key). Both were more compact and both were
  ///     harder to read at a glance, which is the only thing this line is for.
  ///   * **macOS keeps a cap per glyph** — `⇧ ⌘ 1`. Mac shortcuts are written
  ///     without separators, and the glyphs are wide enough to stand alone.
  ///
  /// The registered combination is the same either way; only the label moves.
  String get shortcutDisplay {
    final isWindows = Platform.isWindows;
    final parts = <String>[];
    if (modifiers.contains(HotKeyModifier.control)) {
      parts.add(isWindows ? 'Ctrl' : '⌃');
    }
    if (modifiers.contains(HotKeyModifier.alt)) {
      parts.add(isWindows ? 'Alt' : '⌥');
    }
    if (modifiers.contains(HotKeyModifier.shift)) {
      parts.add(isWindows ? 'Shift' : '⇧');
    }
    if (modifiers.contains(HotKeyModifier.meta)) {
      parts.add(isWindows ? 'Win' : '⌘');
    }
    parts.add(_formatKey(key));
    return isWindows ? parts.join('+') : parts.join(' ');
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
