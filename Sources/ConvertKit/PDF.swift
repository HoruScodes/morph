import CoreGraphics
import Foundation
import PDFKit

nonisolated func openPDF(_ url: URL) throws(ConversionError) -> PDFDocument {
  guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
    throw .unreadable(url.lastPathComponent)
  }
  return document
}

nonisolated func shrinkPDFs(
  _ inputs: [URL], into outputs: inout OutputSet, progress: @Sendable (Double) -> Void
) throws(ConversionError) {
  for (index, url) in inputs.enumerated() {
    let name = url.lastPathComponent
    let document = try openPDF(url)
    let target = outputs.next(stem: stem(of: url) + " (small)", ext: "pdf")
    let options: [PDFDocumentWriteOption: Any] = [
      .saveImagesAsJPEGOption: true,
      .optimizeImagesForScreenOption: true,
    ]
    guard document.write(to: target, withOptions: options) else { throw .failed(name) }
    guard fileSize(target) < fileSize(url) else { throw .alreadySmall(name) }
    progress(Double(index + 1) / Double(inputs.count))
  }
}

nonisolated func mergePDFs(
  _ inputs: [URL], into outputs: inout OutputSet, progress: @Sendable (Double) -> Void
) throws(ConversionError) {
  let merged = PDFDocument()
  for (index, url) in inputs.enumerated() {
    let document = try openPDF(url)
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex)?.copy() as? PDFPage else {
        throw .unreadable(url.lastPathComponent)
      }
      merged.insert(page, at: merged.pageCount)
    }
    progress(Double(index + 1) / Double(inputs.count))
  }
  let first = inputs[0]
  let target = outputs.next(stem: stem(of: first) + " combined", ext: "pdf")
  guard merged.write(to: target) else { throw .failed(first.lastPathComponent) }
}

nonisolated func renderPage(_ page: PDFPage, dpi: Double) -> CGImage? {
  guard let reference = page.pageRef else { return nil }
  let box = reference.getBoxRect(.cropBox)
  let turned = reference.rotationAngle % 180 != 0
  let scale = dpi / 72
  let width = max(1, Int(((turned ? box.height : box.width) * scale).rounded()))
  let height = max(1, Int(((turned ? box.width : box.height) * scale).rounded()))
  let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  guard let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
  ) else { return nil }
  let rect = CGRect(x: 0, y: 0, width: width, height: height)
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(rect)
  context.concatenate(reference.getDrawingTransform(.cropBox, rect: rect, rotate: 0, preserveAspectRatio: true))
  context.drawPDFPage(reference)
  return context.makeImage()
}

nonisolated func pdfsToJPG(
  _ inputs: [URL], into outputs: inout OutputSet, progress: @Sendable (Double) -> Void
) throws(ConversionError) {
  let documents = try inputs.map { url throws(ConversionError) in (url, try openPDF(url)) }
  let totalPages = documents.reduce(0) { $0 + $1.1.pageCount }
  var done = 0
  for (url, document) in documents {
    let name = url.lastPathComponent
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex), let image = renderPage(page, dpi: 150) else {
        throw .failed(name)
      }
      let target = outputs.next(stem: "\(stem(of: url)) page \(pageIndex + 1)", ext: "jpg")
      try writeImage(image, to: target, type: .jpeg, quality: 0.85, name: name)
      done += 1
      progress(Double(done) / Double(totalPages))
    }
  }
}
