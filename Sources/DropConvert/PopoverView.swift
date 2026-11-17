import AppKit
import ConvertKit
import SwiftUI

struct PopoverView: View {
  let model: Model

  var body: some View {
    VStack(spacing: 14) {
      content
      HStack {
        Toggle("Open at login", isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) }))
          .toggleStyle(.checkbox)
        Spacer()
        Button("Quit DropConvert") { NSApp.terminate(nil) }.buttonStyle(.plain)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(width: 320)
    .dropDestination(for: URL.self) { urls, _ in
      model.load(urls)
      return true
    }
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .empty: empty
    case .ready(let files, let actions): ready(files, actions)
    case .working(let action, let progress): working(action, progress)
    case .done(let result): done(result)
    case .failed(let message): failed(message)
    }
  }

  private var empty: some View {
    VStack(spacing: 10) {
      Image(systemName: "arrow.down.doc").font(.system(size: 34)).foregroundStyle(.secondary)
      Text("Drop files here").font(.headline)
      Text("You can also drop them on the menu bar icon. Your files never leave your Mac.")
        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Button("Choose files…") { model.chooseFiles() }.controlSize(.large)
    }
    .frame(maxWidth: .infinity)
  }

  private func ready(_ files: [URL], _ actions: [Action]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      if files.count > 4 {
        Label("\(files.count) files", systemImage: "doc.on.doc").font(.headline)
      } else {
        ForEach(files, id: \.self) { url in
          HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 22, height: 22)
            Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
          }
        }
      }
      if actions.isEmpty {
        Text("These files can't be converted together").foregroundStyle(.secondary)
      }
      ForEach(actions) { action in
        Button { model.run(action) } label: {
          Text(action.title).frame(maxWidth: .infinity)
        }
        .controlSize(.large)
      }
      Button("Start over") { model.reset() }.buttonStyle(.link).font(.callout)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func working(_ action: Action, _ progress: Double) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("\(action.title)…").font(.headline)
      ProgressView(value: progress)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func done(_ result: ConversionResult) -> some View {
    let count = result.outputs.count
    return VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(.green)
      Text(count == 1 ? "Saved 1 file" : "Saved \(count) files").font(.headline)
      Text(sizeSummary(result)).font(.callout).foregroundStyle(.secondary)
      Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(result.outputs) }
        .controlSize(.large)
      Button("Convert more") { model.reset() }.buttonStyle(.link).font(.callout)
    }
    .frame(maxWidth: .infinity)
  }

  private func failed(_ message: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 34)).foregroundStyle(.orange)
      Text(message).multilineTextAlignment(.center)
      Button("Try again") { model.retry() }.controlSize(.large)
    }
    .frame(maxWidth: .infinity)
  }

  private func sizeSummary(_ result: ConversionResult) -> String {
    let before = ByteCountFormatter.string(fromByteCount: result.inputBytes, countStyle: .file)
    let after = ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file)
    let saved = result.percentSaved.map { " · \($0)% smaller" } ?? ""
    return "\(before) → \(after)\(saved)"
  }
}
