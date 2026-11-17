import AppKit
import ConvertKit
import SwiftUI

enum Shots {
  static func render(to directory: URL) {
    let fileManager = FileManager.default
    let samples = fileManager.temporaryDirectory.appendingPathComponent("MorphShots-\(UUID().uuidString)")
    try? fileManager.createDirectory(at: samples, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: samples) }
    func sample(_ name: String) -> URL {
      let url = samples.appendingPathComponent(name)
      fileManager.createFile(atPath: url.path, contents: nil)
      return url
    }

    let photo = [sample("Beach day.heic")]
    let pdfs = [sample("Lease agreement.pdf"), sample("Passport scan.pdf"), sample("Bank letter.pdf")]
    let video = [sample("Birthday.mov")]
    let shrunk = ConversionResult(outputs: photo, inputBytes: 3_932_758, outputBytes: 424_298)
    let states: [(String, Phase)] = [
      ("empty", .empty),
      ("photo", .ready(files: photo, actions: Action.available(for: [.image]))),
      ("pdfs", .ready(files: pdfs, actions: Action.available(for: [.pdf, .pdf, .pdf]))),
      ("video", .ready(files: video, actions: Action.available(for: [.video]))),
      ("working", .working(.shrinkImage, progress: 0.62)),
      ("done", .done(shrunk)),
      ("mixed", .ready(files: photo + video, actions: [])),
    ]
    for (name, phase) in states {
      let view = PopoverView(model: Model(phase: phase, greeting: "Feed me a file"))
        .environment(\.controlActiveState, .key)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      write(view, to: directory.appendingPathComponent("\(name).png"))
    }
    let measured: [(Action, [URL], Int64, Int64, Int)] = [
      (.imageToJPG, photo, 2_340_000, 3_272_910, 1), (.imageToPNG, photo, 2_340_000, 24_293_215, 1),
      (.shrinkImage, photo, 2_340_000, 444_375, 1), (.imagesToPDF, photo, 2_340_000, 3_347_558, 1),
      (.shrinkPDF, pdfs, 21_293_316, 2_936_664, 3), (.mergePDFs, pdfs, 21_293_316, 7_099_450, 1),
      (.pdfToJPG, pdfs, 21_293_316, 846_588, 6), (.shrinkVideo, video, 10_576_793, 4_279_365, 1),
    ]
    for (action, inputs, before, after, count) in measured {
      let outputs = Array(repeating: inputs[0], count: count)
      let result = ConversionResult(outputs: outputs, inputBytes: before, outputBytes: after)
      for (prefix, phase) in [("working", Phase.working(action, progress: 0.62)), ("done", .done(result))] {
        let view = PopoverView(model: Model(phase: phase))
          .environment(\.controlActiveState, .key)
          .background(Color(nsColor: .windowBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        write(view, to: directory.appendingPathComponent("\(prefix)-\(action.rawValue).png"))
      }
    }
    for (name, mood) in [("idle", Mood.idle), ("hungry", .hungry), ("busy", .busy), ("happy", .happy), ("sad", .sad)] {
      write(Image(nsImage: Mascot.image(mood, side: 240)), to: directory.appendingPathComponent("face-\(name).png"))
      let menuBar = Image(nsImage: Mascot.image(mood, side: 240, body: CGColor(gray: 1, alpha: 1)))
      write(menuBar, to: directory.appendingPathComponent("menubar-\(name).png"))
    }
  }

  private static func write(_ view: some View, to url: URL) {
    let host = NSHostingView(rootView: view)
    host.appearance = NSAppearance(named: .aqua)
    let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .aqua)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.contentView = host
    let size = host.fittingSize
    window.setContentSize(size)
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    let scale = 3
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)
    else { return }
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
  }
}
