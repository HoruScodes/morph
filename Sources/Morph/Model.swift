import AppKit
import ConvertKit
import Observation
import ServiceManagement

enum Phase {
  case empty
  case ready(files: [URL], actions: [Action])
  case working(Action, progress: Double)
  case done(ConversionResult)
  case failed(String)
}

@Observable
final class Model {
  private(set) var phase: Phase = .empty {
    didSet { onMoodChange() }
  }
  private(set) var greeting: String

  init(phase: Phase = .empty, greeting: String? = nil) {
    self.phase = phase
    self.greeting = greeting ?? Model.randomGreeting()
  }
  @ObservationIgnored var onMoodChange: () -> Void = {}

  var mood: Mood {
    switch phase {
    case .empty, .ready: .idle
    case .working: .busy
    case .done: .happy
    case .failed: .sad
    }
  }

  private static func randomGreeting() -> String {
    ["Feed me a file", "Got something for me?", "Drop a file on me", "I'm hungry. Files, please"].randomElement() ?? "Feed me a file"
  }
  private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
  private var files: [URL] = []

  func setOpensAtLogin(_ on: Bool) {
    if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
    opensAtLogin = SMAppService.mainApp.status == .enabled
  }

  func load(_ urls: [URL]) {
    if case .working = phase { return }
    let dropped = urls.filter(\.isFileURL)
    guard !dropped.isEmpty else { return }
    show(dropped)
  }

  func chooseFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK else { return }
    load(panel.urls)
  }

  func run(_ action: Action) {
    guard case .ready(let files, _) = phase else { return }
    phase = .working(action, progress: 0)
    Task {
      do {
        let result = try await convert(action, inputs: files) { value in
          Task { @MainActor in self.update(action, progress: value) }
        }
        phase = .done(result)
      } catch {
        phase = .failed(error.localizedDescription)
      }
    }
  }

  func retry() {
    if files.isEmpty { reset() } else { show(files) }
  }

  func reset() {
    files = []
    greeting = Model.randomGreeting()
    phase = .empty
  }

  private func show(_ urls: [URL]) {
    files = urls
    let kinds = urls.compactMap(FileKind.init(url:))
    let actions = kinds.count == urls.count ? Action.available(for: kinds) : []
    phase = .ready(files: urls, actions: actions)
  }

  private func update(_ action: Action, progress: Double) {
    guard case .working(let current, _) = phase, current == action else { return }
    phase = .working(action, progress: progress)
  }
}
