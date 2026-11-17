import AppKit
import SwiftUI

final class StatusItemController: NSObject, NSPopoverDelegate {
  private let model = Model()
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let popover = NSPopover()
  private var isDragHovering = false

  override init() {
    super.init()

    let host = NSHostingController(rootView: PopoverView(model: model))
    host.sizingOptions = [.preferredContentSize]
    popover.contentViewController = host
    popover.behavior = .transient
    popover.delegate = self

    guard let button = statusItem.button else { return }
    button.toolTip = "Morph"
    button.setAccessibilityLabel("Morph")
    model.onMoodChange = { [weak self] in self?.refreshFace() }
    refreshFace()
    button.target = self
    button.action = #selector(toggle)

    let dropView = DropView(frame: button.bounds)
    dropView.autoresizingMask = [.width, .height]
    dropView.onClick = { [weak button] in button?.performClick(nil) }
    dropView.onHighlight = { [weak self] on in
      self?.isDragHovering = on
      self?.refreshFace()
    }
    dropView.onDrop = { [weak self] urls in
      self?.model.load(urls)
      self?.show()
    }
    button.addSubview(dropView)
  }

  func popoverShouldClose(_ popover: NSPopover) -> Bool { NSApp.modalWindow == nil }

  private func refreshFace() {
    statusItem.button?.image = Mascot.menuBarImage(isDragHovering ? .hungry : model.mood)
  }

  @objc private func toggle() {
    if popover.isShown { popover.performClose(nil) } else { show() }
  }

  private func show() {
    guard let button = statusItem.button, !popover.isShown else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    NSApp.activate()
    popover.contentViewController?.view.window?.makeKey()
  }
}
