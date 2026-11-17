import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("DropConvert-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: 1024, height: 1024)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
  let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
  shadow.shadowOffset = NSSize(width: 0, height: -10)
  shadow.shadowBlurRadius = 24
  NSGraphicsContext.saveGraphicsState()
  shadow.set()
  NSColor.white.setFill()
  shape.fill()
  NSGraphicsContext.restoreGraphicsState()
  NSGradient(
    starting: NSColor(srgbRed: 0.33, green: 0.62, blue: 1.0, alpha: 1),
    ending: NSColor(srgbRed: 0.09, green: 0.30, blue: 0.86, alpha: 1)
  )!.draw(in: shape, angle: -90)

  let configuration = NSImage.SymbolConfiguration(pointSize: 440, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
  let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)!
    .withSymbolConfiguration(configuration)!
  let size = symbol.size
  symbol.draw(in: NSRect(x: tile.midX - size.width / 2, y: tile.midY - size.height / 2, width: size.width, height: size.height))

  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
  try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
  try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
