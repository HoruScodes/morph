import AppKit

final class DropView: NSView {
  var onDrop: ([URL]) -> Void = { _ in }
  var onClick: () -> Void = {}
  var onHighlight: (Bool) -> Void = { _ in }

  override init(frame: NSRect) {
    super.init(frame: frame)
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) { nil }

  override func mouseDown(with event: NSEvent) { onClick() }

  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard !fileURLs(from: sender).isEmpty else { return [] }
    onHighlight(true)
    return .copy
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) { onHighlight(false) }

  override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { true }

  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    onHighlight(false)
    let urls = fileURLs(from: sender)
    guard !urls.isEmpty else { return false }
    onDrop(urls)
    return true
  }

  private func fileURLs(from info: any NSDraggingInfo) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
  }
}
