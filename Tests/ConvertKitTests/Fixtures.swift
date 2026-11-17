import CoreGraphics
import CoreText
import ConvertKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
let fixtureText = "DropConvert fixture text"

func withSandbox(_ body: (URL) async throws -> Void) async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("DropConvertTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  try await body(directory)
}

struct FixtureError: Error { let message: String }

func run(_ executable: String, _ arguments: [String]) throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    throw FixtureError(message: "\(executable) exited with \(process.terminationStatus)")
  }
}

func busyImage(width: Int, height: Int) throws -> CGImage {
  guard let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
  ), let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [CGColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1), CGColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1)] as CFArray,
    locations: [0, 1]
  ) else { throw FixtureError(message: "bitmap context") }
  context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
  var state: UInt64 = 42
  func next() -> CGFloat {
    state = state &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(state >> 40) / CGFloat(1 << 24)
  }
  for _ in 0..<1500 {
    context.setFillColor(CGColor(red: next(), green: next(), blue: next(), alpha: 1))
    let side = 8 + next() * CGFloat(min(width, height)) / 12
    context.fill(CGRect(x: next() * CGFloat(width), y: next() * CGFloat(height), width: side, height: side))
  }
  guard let image = context.makeImage() else { throw FixtureError(message: "makeImage") }
  return image
}

func writeImage(_ image: CGImage, to url: URL, type: UTType, properties: [CFString: Any] = [:]) throws {
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
    throw FixtureError(message: "destination")
  }
  CGImageDestinationAddImage(destination, image, properties as CFDictionary)
  guard CGImageDestinationFinalize(destination) else { throw FixtureError(message: "finalize") }
}

@discardableResult
func makePNG(in directory: URL, name: String = "photo", width: Int = 640, height: Int = 480) throws -> URL {
  let url = directory.appendingPathComponent("\(name).png")
  try writeImage(try busyImage(width: width, height: height), to: url, type: .png)
  return url
}

func makeHEIC(in directory: URL, name: String = "photo") throws -> URL {
  let png = try makePNG(in: directory, name: name)
  let heic = directory.appendingPathComponent("\(name).heic")
  try run("/usr/bin/sips", ["-s", "format", "heic", png.path, "--out", heic.path])
  try FileManager.default.removeItem(at: png)
  return heic
}

func makePDF(in directory: URL, name: String, pages: Int, bigImage: Bool = false) throws -> URL {
  let url = directory.appendingPathComponent("\(name).pdf")
  var box = CGRect(x: 0, y: 0, width: 612, height: 792)
  guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw FixtureError(message: "pdf") }
  let image = bigImage ? try busyImage(width: 3000, height: 3000) : nil
  let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
  for page in 1...pages {
    context.beginPDFPage(nil)
    if let image { context.draw(image, in: CGRect(x: 36, y: 36, width: 540, height: 540)) }
    let text = NSAttributedString(string: "\(fixtureText) \(page)", attributes: [.font: font])
    context.textPosition = CGPoint(x: 36, y: 700)
    CTLineDraw(CTLineCreateWithAttributedString(text), context)
    context.endPDFPage()
  }
  context.closePDF()
  return url
}

func makeVideo(in directory: URL) throws -> URL {
  let url = directory.appendingPathComponent("clip.mp4")
  try run(ffmpegPath, [
    "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=1920x1080:rate=30",
    "-pix_fmt", "yuv420p", "-b:v", "15M", url.path,
  ])
  return url
}

struct ImageInfo { let type: String?; let width: Int; let height: Int; let orientation: Int? }

func imageInfo(_ url: URL) -> ImageInfo? {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
    let width = properties[kCGImagePropertyPixelWidth] as? Int,
    let height = properties[kCGImagePropertyPixelHeight] as? Int
  else { return nil }
  return ImageInfo(
    type: CGImageSourceGetType(source) as String?, width: width, height: height,
    orientation: properties[kCGImagePropertyOrientation] as? Int
  )
}

func firstOutput(_ result: ConversionResult) throws -> URL {
  guard let url = result.outputs.first else { throw FixtureError(message: "no output") }
  return url
}

func loadInfo(_ url: URL) throws -> ImageInfo {
  guard let info = imageInfo(url) else { throw FixtureError(message: "undecodable image \(url.lastPathComponent)") }
  return info
}

func loadPDF(_ url: URL) throws -> PDFDocument {
  guard let document = PDFDocument(url: url) else { throw FixtureError(message: "unreadable pdf \(url.lastPathComponent)") }
  return document
}

func convertToFirstOutput(_ action: Action, _ inputs: [URL]) async throws -> URL {
  try firstOutput(try await convert(action, inputs: inputs, progress: { _ in }))
}
