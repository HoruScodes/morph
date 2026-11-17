import Foundation
import UniformTypeIdentifiers

public nonisolated enum FileKind: Sendable {
  case image, pdf, video

  public init?(url: URL) {
    let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
      ?? UTType(filenameExtension: url.pathExtension)
    guard let type else { return nil }
    if type.conforms(to: .pdf) {
      self = .pdf
    } else if type.conforms(to: .movie) {
      self = .video
    } else if type.conforms(to: .image) {
      self = .image
    } else {
      return nil
    }
  }
}

public nonisolated enum Action: String, CaseIterable, Sendable, Identifiable {
  case imageToJPG, imageToPNG, shrinkImage, imagesToPDF,
       shrinkPDF, mergePDFs, pdfToJPG, shrinkVideo

  public var id: String { rawValue }
  public var title: String { spec.title }
  public var inputKind: FileKind { spec.kind }
  public var minimumInputs: Int { spec.minimum }

  private var spec: (title: String, kind: FileKind, minimum: Int) {
    switch self {
    case .imageToJPG: ("Convert to JPG", .image, 1)
    case .imageToPNG: ("Convert to PNG", .image, 1)
    case .shrinkImage: ("Make smaller", .image, 1)
    case .imagesToPDF: ("Turn into a PDF", .image, 1)
    case .shrinkPDF: ("Make smaller", .pdf, 1)
    case .mergePDFs: ("Combine into one PDF", .pdf, 2)
    case .pdfToJPG: ("Save pages as JPG", .pdf, 1)
    case .shrinkVideo: ("Make smaller", .video, 1)
    }
  }

  public static func available(for kinds: [FileKind]) -> [Action] {
    guard let kind = kinds.first, kinds.allSatisfy({ $0 == kind }) else { return [] }
    return allCases.filter { $0.inputKind == kind && kinds.count >= $0.minimumInputs }
  }
}
