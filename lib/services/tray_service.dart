import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The menu-bar icon that replaces the Dock icon now that the app is
/// `LSUIElement` (no Dock presence, not in Cmd+Tab). Its menu is the only
/// way left to bring the window back or fully quit.
class TrayService with TrayListener {
  static const _appChannel = MethodChannel('com.dochi.tide/app');

  Future<void> initialize() async {
    trayManager.addListener(this);
    await trayManager.setIcon(
      'assets/tray/tide-menubar-template.png',
      isTemplate: true,
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show Dashboard'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit Tide Completely'),
        ],
      ),
    );
  }

  void dispose() {
    trayManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'quit':
        // Forwards to `AppDelegate.quitCompletely()` — the one path allowed
        // to actually terminate (everything else, including Cmd+Q, just
        // hides the window; see `AppDelegate.swift`).
        _appChannel.invokeMethod('quitCompletely');
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
