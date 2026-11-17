import Foundation

public nonisolated struct ConversionResult: Sendable {
  public let outputs: [URL]
  public let inputBytes: Int64
  public let outputBytes: Int64

  public init(outputs: [URL], inputBytes: Int64, outputBytes: Int64) {
    self.outputs = outputs
    self.inputBytes = inputBytes
    self.outputBytes = outputBytes
  }

  public var percentSaved: Int? {
    guard inputBytes > 0, outputBytes < inputBytes else { return nil }
    return Int((Double(inputBytes - outputBytes) / Double(inputBytes) * 100).rounded())
  }
}

nonisolated struct OutputSet {
  let directory: URL
  private(set) var urls: [URL] = []

  init(directory: URL) { self.directory = directory }

  mutating func next(stem: String, ext: String) -> URL {
    let fileManager = FileManager.default
    var candidate = directory.appendingPathComponent(stem).appendingPathExtension(ext)
    var counter = 2
    while fileManager.fileExists(atPath: candidate.path) {
      candidate = directory.appendingPathComponent("\(stem) \(counter)").appendingPathExtension(ext)
      counter += 1
    }
    urls.append(candidate)
    return candidate
  }

  func removeAll() {
    for url in urls { try? FileManager.default.removeItem(at: url) }
  }
}

nonisolated func fileSize(_ url: URL) -> Int64 {
  (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
}

nonisolated func stem(of url: URL) -> String {
  url.deletingPathExtension().lastPathComponent
}

@concurrent
public func convert(
  _ action: Action,
  inputs: [URL],
  progress: @Sendable (Double) -> Void
) async throws(ConversionError) -> ConversionResult {
  guard let first = inputs.first, inputs.count >= action.minimumInputs else {
    throw .notEnoughFiles(needed: action.minimumInputs)
  }
  for url in inputs where FileKind(url: url) != action.inputKind {
    throw .unsupported(url.lastPathComponent)
  }

  var outputs = OutputSet(directory: first.deletingLastPathComponent())
  do {
    switch action {
    case .imageToJPG: try convertImages(inputs, recipe: .jpg, into: &outputs, progress: progress)
    case .imageToPNG: try convertImages(inputs, recipe: .png, into: &outputs, progress: progress)
    case .shrinkImage: try convertImages(inputs, recipe: .small, into: &outputs, progress: progress)
    case .imagesToPDF: try imagesToPDF(inputs, into: &outputs, progress: progress)
    case .shrinkPDF: try shrinkPDFs(inputs, into: &outputs, progress: progress)
    case .mergePDFs: try mergePDFs(inputs, into: &outputs, progress: progress)
    case .pdfToJPG: try pdfsToJPG(inputs, into: &outputs, progress: progress)
    case .shrinkVideo: try await shrinkVideos(inputs, into: &outputs, progress: progress)
    }
  } catch {
    outputs.removeAll()
    throw error
  }

  progress(1)
  return ConversionResult(
    outputs: outputs.urls,
    inputBytes: inputs.reduce(0) { $0 + fileSize($1) },
    outputBytes: outputs.urls.reduce(0) { $0 + fileSize($1) }
  )
}
