import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import '../models/capture_mode.dart';
import '../models/hotkey_config.dart';

typedef HotkeyActionCallback = void Function(AppCaptureMode action);

/// Registers the two fixed global shortcuts (⇧⌘1 / ⇧⌘2) with the OS.
/// There's no UI to change them — see Non-goals in the guideline doc.
class HotkeyService {
  final List<HotkeyConfig> configs;
  final HotkeyActionCallback onActionTriggered;
  bool _isRegistered = false;

  HotkeyService({
    required this.configs,
    required this.onActionTriggered,
  });

  bool get isRegistered => _isRegistered;

  Future<void> registerAll() async {
    try {
      await hotKeyManager.unregisterAll();

      for (final config in configs) {
        await hotKeyManager.register(
          config.toHotKey(),
          keyDownHandler: (_) {
            debugPrint('Global hotkey triggered: ${config.action.displayName}');
            onActionTriggered(config.action);
          },
        );
      }
      _isRegistered = true;
      debugPrint('Registered ${configs.length} global hotkeys.');
    } catch (e) {
      debugPrint('Error registering global hotkeys: $e');
      _isRegistered = false;
    }
  }

  Future<void> unregisterAll() async {
    try {
      await hotKeyManager.unregisterAll();
      _isRegistered = false;
    } catch (e) {
      debugPrint('Error unregistering hotkeys: $e');
    }
  }
}
