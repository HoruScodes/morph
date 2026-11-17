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
    if let flag = CommandLine.arguments.firstIndex(of: "--shots"), CommandLine.arguments.count > flag + 1 {
      Shots.render(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
      return
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
