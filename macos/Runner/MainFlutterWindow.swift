import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The close button must hide the window, not deallocate it — otherwise
    // "closed but still running for the hotkeys" (AppDelegate) has no window
    // left to bring back on Dock-icon reopen.
    self.isReleasedWhenClosed = false

    // The tray icon's "Quit Tide Completely" item (Dart, `TrayService`) is
    // the only thing allowed to actually terminate the process now that
    // `applicationShouldTerminate` intercepts everything else — that logic
    // lives in the app delegate, so this just forwards to it.
    let quitChannel = FlutterMethodChannel(
      name: "com.dochi.tide/app",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    quitChannel.setMethodCallHandler { call, result in
      if call.method == "quitCompletely" {
        (NSApp.delegate as? AppDelegate)?.quitCompletely()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
