import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Set only by `quitCompletely()` below — the one path that's allowed to
  // actually end the process. Everything else (close button, Cmd+Q, Dock
  // "Quit") just hides the window, because the global capture shortcuts are
  // registered on this process, not the window (2026-09-24 product decision
  // — Cmd+Q intentionally does NOT quit, unlike every other Mac app).
  private var allowRealTermination = false

  // Closing the window must not quit the app. `MainFlutterWindow
  // .isReleasedWhenClosed = false` keeps the window object (and its
  // FlutterViewController/engine) alive when hidden.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Cmd+Q / Dock "Quit" also goes through here. Without `allowRealTermination`,
  // hide instead of quitting.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if allowRealTermination {
      return .terminateNow
    }
    for window in NSApp.windows {
      window.orderOut(nil)
    }
    return .terminateCancel
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    addQuitCompletelyMenuItem()
  }

  // The standard "Quit Tide" (⌘Q) item no longer really quits, so there
  // needs to be *some* way to. No tray icon exists yet to hold a proper one.
  private func addQuitCompletelyMenuItem() {
    guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
    let item = NSMenuItem(
      title: "Quit Tide Completely",
      action: #selector(quitCompletely),
      keyEquivalent: "q"
    )
    item.keyEquivalentModifierMask = [.command, .option]
    item.target = self
    appMenu.addItem(item)
  }

  @objc private func quitCompletely() {
    allowRealTermination = true
    NSApp.terminate(nil)
  }

  // Clicking the Dock icon with no visible windows re-shows the (still
  // alive, just hidden) main window instead of doing nothing.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows {
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(self)
      }
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
