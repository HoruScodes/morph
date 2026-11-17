import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

nonisolated struct ImageRecipe {
  let type: UTType
  let ext: String
  let quality: Double?
  let maxPixel: Int?
  let suffix: String

  static let jpg = ImageRecipe(type: .jpeg, ext: "jpg", quality: 0.85, maxPixel: nil, suffix: "")
  static let png = ImageRecipe(type: .png, ext: "png", quality: nil, maxPixel: nil, suffix: "")
  static let small = ImageRecipe(type: .jpeg, ext: "jpg", quality: 0.7, maxPixel: 2000, suffix: " (small)")
}

nonisolated func loadImage(_ url: URL, maxPixel: Int?) throws(ConversionError) -> CGImage {
  let name = url.lastPathComponent
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    CGImageSourceGetCount(source) > 0,
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
    let width = properties[kCGImagePropertyPixelWidth] as? Int,
    let height = properties[kCGImagePropertyPixelHeight] as? Int
  else { throw .unreadable(name) }

  let longest = max(width, height)
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceThumbnailMaxPixelSize: min(longest, maxPixel ?? longest),
  ]
  guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
    throw .unreadable(name)
  }
  return image
}

nonisolated func flattenedOnWhite(_ image: CGImage) -> CGImage? {
  switch image.alphaInfo {
  case .none, .noneSkipFirst, .noneSkipLast: return image
  default: break
  }
  let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  guard let context = CGContext(
    data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
  ) else { return nil }
  let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(rect)
  context.draw(image, in: rect)
  return context.makeImage()
}

nonisolated func writeImage(
  _ image: CGImage, to url: URL, type: UTType, quality: Double?, name: String
) throws(ConversionError) {
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
    throw .failed(name)
  }
  var properties: [CFString: Any] = [:]
  if let quality { properties[kCGImageDestinationLossyCompressionQuality] = quality }
  CGImageDestinationAddImage(destination, image, properties as CFDictionary)
  guard CGImageDestinationFinalize(destination) else { throw .failed(name) }
}

nonisolated func convertImages(
  _ inputs: [URL], recipe: ImageRecipe, into outputs: inout OutputSet,
  progress: @Sendable (Double) -> Void
) throws(ConversionError) {
  for (index, url) in inputs.enumerated() {
    let name = url.lastPathComponent
    var image = try loadImage(url, maxPixel: recipe.maxPixel)
    if recipe.type == .jpeg {
      guard let flat = flattenedOnWhite(image) else { throw .failed(name) }
      image = flat
    }
    let target = outputs.next(stem: stem(of: url) + recipe.suffix, ext: recipe.ext)
    try writeImage(image, to: target, type: recipe.type, quality: recipe.quality, name: name)
    if recipe.maxPixel != nil { outputs.keepLastOnlyIfSmaller(than: url) }
    progress(Double(index + 1) / Double(inputs.count))
  }
}

nonisolated func imagesToPDF(
  _ inputs: [URL], into outputs: inout OutputSet, progress: @Sendable (Double) -> Void
) throws(ConversionError) {
  let first = inputs[0]
  let document = PDFDocument()
  for (index, url) in inputs.enumerated() {
    let image = try loadImage(url, maxPixel: nil)
    let scale = min(1, 842 / Double(max(image.width, image.height)))
    let size = NSSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
    guard let page = PDFPage(image: NSImage(cgImage: image, size: size)) else {
      throw .failed(url.lastPathComponent)
    }
    document.insert(page, at: document.pageCount)
    progress(Double(index + 1) / Double(inputs.count))
  }
  let target = outputs.next(stem: stem(of: first) + (inputs.count > 1 ? " combined" : ""), ext: "pdf")
  // Without this PDFKit stores every photo uncompressed, about eight times the size of the JPEG.
  guard document.write(to: target, withOptions: [.saveImagesAsJPEGOption: true]) else {
    throw .failed(first.lastPathComponent)
  }
}
