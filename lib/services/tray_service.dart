import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The menu-bar (macOS) / notification-area (Windows) icon that stands in for
/// a Dock or taskbar entry, since the app hides itself from both. Its menu is
/// the only way left to bring the window back or fully quit.
class TrayService with TrayListener {
  static const _appChannel = MethodChannel('com.dochi.tide/app');

  /// macOS renders a *template* image — monochrome plus alpha, which the OS
  /// recolours for light/dark menu bars. Windows does no such recolouring and
  /// would show that asset as a black smudge, so it gets its own real-colour
  /// icon, and `.ico` so Windows can pick the right size per DPI.
  static String get _iconPath => Platform.isWindows
      ? 'assets/tray/tide-tray.ico'
      : 'assets/tray/tide-menubar-template.png';

  Future<void> initialize() async {
    trayManager.addListener(this);
    await trayManager.setIcon(_iconPath, isTemplate: !Platform.isWindows);
    if (Platform.isWindows) {
      // Windows shows this on hover; without it the icon is anonymous in the
      // overflow tray.
      await trayManager.setToolTip('Tide');
    }
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
    // Windows convention splits the buttons: left-click opens the app,
    // right-click opens the menu. macOS puts the menu on both.
    if (Platform.isWindows) {
      _showWindow();
    } else {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'quit':
        _quitCompletely();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitCompletely() async {
    if (Platform.isWindows) {
      // No AppDelegate to defer to. `destroy()` is the one exit that skips
      // the preventClose guard `main.dart` installs to keep the close button
      // from ending the process.
      await windowManager.destroy();
      return;
    }
    // Forwards to `AppDelegate.quitCompletely()` — the one path allowed
    // to actually terminate (everything else, including Cmd+Q, just
    // hides the window; see `AppDelegate.swift`).
    await _appChannel.invokeMethod('quitCompletely');
  }
}
