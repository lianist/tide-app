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

    super.awakeFromNib()
  }
}
