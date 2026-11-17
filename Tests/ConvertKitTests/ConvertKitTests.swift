import AVFoundation
import ConvertKit
import Foundation
import PDFKit
import Testing

struct KindsCase: CustomTestStringConvertible, Sendable {
  let label: String
  let kinds: [FileKind]
  let expected: [Action]
  var testDescription: String { label }
}

@Suite struct ActionTable {
  @Test(arguments: [
    KindsCase(label: "images only", kinds: [.image, .image],
              expected: [.imageToJPG, .imageToPNG, .shrinkImage, .imagesToPDF]),
    KindsCase(label: "one pdf", kinds: [.pdf], expected: [.shrinkPDF, .pdfToJPG]),
    KindsCase(label: "two pdfs", kinds: [.pdf, .pdf], expected: [.shrinkPDF, .mergePDFs, .pdfToJPG]),
    KindsCase(label: "video", kinds: [.video], expected: [.shrinkVideo]),
    KindsCase(label: "mixed kinds", kinds: [.image, .pdf], expected: []),
    KindsCase(label: "empty", kinds: [], expected: []),
  ])
  func offersOnlyWhatFits(_ testCase: KindsCase) {
    #expect(Action.available(for: testCase.kinds) == testCase.expected)
  }

  @Test func titlesUsePlainWords() {
    #expect(Action.mergePDFs.title == "Combine into one PDF")
    #expect(Action.mergePDFs.minimumInputs == 2)
  }
}

@Suite struct Images {
  @Test func heicBecomesJPEGWithSameDimensions() async throws {
    try await withSandbox { directory in
      let heic = try makeHEIC(in: directory)
      let source = try loadInfo(heic)
      let result = try await convert(.imageToJPG, inputs: [heic], progress: { _ in })
      let output = try firstOutput(result)
      let info = try loadInfo(output)
      #expect(output.lastPathComponent == "photo.jpg")
      #expect(info.type == "public.jpeg")
      #expect(info.width == source.width && info.height == source.height)
    }
  }

  @Test func jpegBecomesPNG() async throws {
    try await withSandbox { directory in
      let png = try makePNG(in: directory)
      let jpg = try await convertToFirstOutput(.imageToJPG, [png])
      let result = try await convert(.imageToPNG, inputs: [jpg], progress: { _ in })
      let info = try loadInfo(try firstOutput(result))
      #expect(info.type == "public.png")
    }
  }

  @Test func rotatedPhotoIsStoredUpright() async throws {
    try await withSandbox { directory in
      let url = directory.appendingPathComponent("sideways.jpg")
      try writeImage(try busyImage(width: 300, height: 200), to: url, type: .jpeg,
                     properties: [kCGImagePropertyOrientation: 6])
      #expect(imageInfo(url)?.orientation == 6)
      let result = try await convert(.imageToJPG, inputs: [url], progress: { _ in })
      let info = try loadInfo(try firstOutput(result))
      #expect(info.width == 200 && info.height == 300)
      #expect((info.orientation ?? 1) == 1)
    }
  }

  @Test(arguments: [(4000, 3000, 2000, 1500, true), (800, 600, 800, 600, false)])
  func shrinkCapsLongestSideWithoutUpscaling(
    width: Int, height: Int, expectedWidth: Int, expectedHeight: Int, expectSmallerFile: Bool
  ) async throws {
    try await withSandbox { directory in
      let png = try makePNG(in: directory, width: width, height: height)
      let result = try await convert(.shrinkImage, inputs: [png], progress: { _ in })
      let output = try firstOutput(result)
      let info = try loadInfo(output)
      #expect(output.lastPathComponent == "photo (small).jpg")
      #expect(info.width == expectedWidth && info.height == expectedHeight)
      if expectSmallerFile { #expect(result.outputBytes < result.inputBytes) }
    }
  }

  @Test func threeImagesBecomeThreePDFPages() async throws {
    try await withSandbox { directory in
      let inputs = try (1...3).map { try makePNG(in: directory, name: "page\($0)", width: 200 * $0, height: 300) }
      let result = try await convert(.imagesToPDF, inputs: inputs, progress: { _ in })
      let document = try loadPDF(try firstOutput(result))
      #expect(result.outputs.count == 1)
      #expect(document.pageCount == 3)
      #expect(document.page(at: 2)?.bounds(for: .mediaBox).width == 600)
    }
  }
}

@Suite struct PDFs {
  @Test func mergeKeepsEveryPageInOrder() async throws {
    try await withSandbox { directory in
      let first = try makePDF(in: directory, name: "a", pages: 2)
      let second = try makePDF(in: directory, name: "b", pages: 3)
      let result = try await convert(.mergePDFs, inputs: [first, second], progress: { _ in })
      let merged = try loadPDF(try firstOutput(result))
      #expect(merged.pageCount == 5)
      #expect(merged.page(at: 2)?.string?.contains("\(fixtureText) 1") == true)
    }
  }

  @Test func shrinkIsSmallerAndKeepsSelectableText() async throws {
    try await withSandbox { directory in
      let pdf = try makePDF(in: directory, name: "report", pages: 3, bigImage: true)
      let result = try await convert(.shrinkPDF, inputs: [pdf], progress: { _ in })
      let output = try firstOutput(result)
      let document = try loadPDF(output)
      #expect(output.lastPathComponent == "report (small).pdf")
      #expect(result.outputBytes < result.inputBytes)
      #expect(document.pageCount == 3)
      #expect(document.string?.contains(fixtureText) == true)
    }
  }

  @Test func shrinkingAgainEventuallySaysAlreadySmallAndLeavesNoStrayFile() async throws {
    try await withSandbox { directory in
      var current = try makePDF(in: directory, name: "report", pages: 2, bigImage: true)
      var shrinks = 0
      var refusal: ConversionError?
      while refusal == nil && shrinks < 6 {
        do {
          current = try await convertToFirstOutput(.shrinkPDF, [current])
          shrinks += 1
        } catch let error as ConversionError {
          refusal = error
        }
      }
      #expect(refusal == .alreadySmall(current.lastPathComponent))
      #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == shrinks + 1)
    }
  }

  @Test func pdfToJPGWritesOneFilePerPage() async throws {
    try await withSandbox { directory in
      let pdf = try makePDF(in: directory, name: "slides", pages: 3)
      let result = try await convert(.pdfToJPG, inputs: [pdf], progress: { _ in })
      #expect(result.outputs.map(\.lastPathComponent) == ["slides page 1.jpg", "slides page 2.jpg", "slides page 3.jpg"])
      let info = try loadInfo(result.outputs[0])
      #expect(info.type == "public.jpeg")
      #expect(info.width == 1275 && info.height == 1650)
    }
  }
}

@Suite struct Video {
  @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: ffmpegPath)))
  func shrinkProducesSmallerPlayableMP4() async throws {
    try await withSandbox { directory in
      let clip = try makeVideo(in: directory)
      var fractions: [Double] = []
      let recorder = Recorder()
      let result = try await convert(.shrinkVideo, inputs: [clip], progress: { recorder.add($0) })
      fractions = recorder.values
      let output = try firstOutput(result)
      let asset = AVURLAsset(url: output)
      let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
      let size = try await track.load(.naturalSize)
      #expect(output.pathExtension == "mp4")
      #expect(size.height <= 720)
      #expect(try await asset.load(.isPlayable))
      #expect(result.outputBytes < result.inputBytes)
      #expect(fractions.last == 1)
      #expect(fractions == fractions.sorted())
    }
  }
}

final class Recorder: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: [Double] = []
  func add(_ value: Double) { lock.withLock { stored.append(value) } }
  var values: [Double] { lock.withLock { stored } }
}

@Suite struct OutputNaming {
  @Test func secondRunGetsANumberAndLeavesTheFirstUntouched() async throws {
    try await withSandbox { directory in
      let png = try makePNG(in: directory)
      let first = try await convertToFirstOutput(.imageToJPG, [png])
      let before = try Data(contentsOf: first)
      let second = try await convertToFirstOutput(.imageToJPG, [png])
      #expect(first.lastPathComponent == "photo.jpg")
      #expect(second.lastPathComponent == "photo 2.jpg")
      #expect(try Data(contentsOf: first) == before)
    }
  }

  @Test func unsupportedFileThrowsAndCreatesNothing() async throws {
    try await withSandbox { directory in
      let note = directory.appendingPathComponent("notes.txt")
      try Data("hello".utf8).write(to: note)
      await #expect(throws: ConversionError.unsupported("notes.txt")) {
        try await convert(.imageToJPG, inputs: [note], progress: { _ in })
      }
      #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["notes.txt"])
    }
  }

  @Test func damagedImageIsReportedByName() async throws {
    try await withSandbox { directory in
      let broken = directory.appendingPathComponent("broken.png")
      try Data("not a png".utf8).write(to: broken)
      await #expect(throws: ConversionError.unreadable("broken.png")) {
        try await convert(.imageToJPG, inputs: [broken], progress: { _ in })
      }
      #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["broken.png"])
    }
  }
}
