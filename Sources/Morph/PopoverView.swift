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
        Button("Quit Morph") { NSApp.terminate(nil) }.buttonStyle(.plain)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(width: 320)
    .tint(Color(red: 0.42, green: 0.29, blue: 0.90))
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

  private func face(_ mood: Mood, side: CGFloat = 72) -> some View {
    Image(nsImage: Mascot.image(mood, side: side)).accessibilityHidden(true)
  }

  private var empty: some View {
    VStack(spacing: 10) {
      face(.idle)
      Text(model.greeting).font(.headline)
      Text("Photos, PDFs and videos. Nothing ever leaves your Mac.")
        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Button("Choose files…") { model.chooseFiles() }.buttonStyle(.borderedProminent).controlSize(.large)
    }
    .frame(maxWidth: .infinity)
  }

  private func ready(_ files: [URL], _ actions: [Action]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        face(actions.isEmpty ? .sad : .hungry, side: 36)
        Text(readyHeadline(files.count, canHelp: !actions.isEmpty)).font(.headline)
      }
      if files.count > 4 {
        Label("\(files.count) files", systemImage: "doc.on.doc")
      } else {
        ForEach(files, id: \.self) { url in
          HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 22, height: 22)
            Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
          }
        }
      }
      if actions.isEmpty {
        Text("Give me one kind at a time: only photos, only PDFs or only videos.")
          .font(.callout).foregroundStyle(.secondary)
      }
      ForEach(actions) { action in
        Button { model.run(action) } label: {
          Text(action.title).fontWeight(.medium).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
      Button("Start over") { model.reset() }.buttonStyle(.link).font(.callout)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func working(_ action: Action, _ progress: Double) -> some View {
    VStack(spacing: 10) {
      face(.busy)
      Text("Morphing…").font(.headline)
      ProgressView(value: progress)
      Text(action.title).font(.callout).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func done(_ result: ConversionResult) -> some View {
    let count = result.outputs.count
    return VStack(spacing: 10) {
      face(.happy)
      Text(doneHeadline(result)).font(.headline)
      Text("\(count == 1 ? "1 file saved next to the original" : "\(count) files saved next to the originals") · \(sizeSummary(result))")
        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(result.outputs) }
        .buttonStyle(.borderedProminent).controlSize(.large)
      Button("Morph something else") { model.reset() }.buttonStyle(.link).font(.callout)
    }
    .frame(maxWidth: .infinity)
  }

  private func failed(_ message: String) -> some View {
    VStack(spacing: 10) {
      face(.sad)
      Text("Hmm, that didn't work").font(.headline)
      Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Button("Try again") { model.retry() }.buttonStyle(.borderedProminent).controlSize(.large)
    }
    .frame(maxWidth: .infinity)
  }

  private func readyHeadline(_ count: Int, canHelp: Bool) -> String {
    guard canHelp else { return "I can't mix these" }
    return count == 1 ? "What should I do with this?" : "What should I do with these?"
  }

  private func doneHeadline(_ result: ConversionResult) -> String {
    guard let saved = result.percentSaved else { return "Ta-da! All done" }
    return saved >= 50 ? "Ta-da! \(saved)% lighter" : "Done! \(saved)% lighter"
  }

  private func sizeSummary(_ result: ConversionResult) -> String {
    let before = ByteCountFormatter.string(fromByteCount: result.inputBytes, countStyle: .file)
    let after = ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file)
    return "\(before) → \(after)"
  }
}
