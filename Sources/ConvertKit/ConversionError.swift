import Foundation

public nonisolated enum ConversionError: Error, LocalizedError, Sendable, Equatable {
  case unsupported(String)
  case unreadable(String)
  case alreadySmall(String)
  case failed(String)
  case notEnoughFiles(needed: Int)

  public var errorDescription: String? {
    switch self {
    case .unsupported(let name):
      "I can't do that with “\(name)”. Try a photo, a PDF or a video."
    case .unreadable(let name):
      "I couldn't open “\(name)”. It may be damaged or locked."
    case .alreadySmall(let name):
      "“\(name)” is already as small as it gets. Nothing left to squeeze."
    case .failed(let name):
      "Something went wrong with “\(name)”. I didn't save anything."
    case .notEnoughFiles(let needed):
      "I need at least \(needed) files for this."
    }
  }
}
