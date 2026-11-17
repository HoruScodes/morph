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
      "“\(name)” isn't a kind of file DropConvert can use for this."
    case .unreadable(let name):
      "DropConvert couldn't open “\(name)”. It may be damaged or locked."
    case .alreadySmall(let name):
      "“\(name)” is already as small as it gets."
    case .failed(let name):
      "Something went wrong with “\(name)”. Nothing was saved."
    case .notEnoughFiles(let needed):
      "Choose at least \(needed) files for this."
    }
  }
}
