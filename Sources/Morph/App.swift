import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var controller: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    controller = StatusItemController()
  }
}

@main
enum MorphApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
