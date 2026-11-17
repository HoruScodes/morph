import AVFoundation
import Foundation

nonisolated func shrinkVideos(
  _ inputs: [URL], into outputs: inout OutputSet, progress: @Sendable (Double) -> Void
) async throws(ConversionError) {
  for (index, url) in inputs.enumerated() {
    let name = url.lastPathComponent
    let asset = AVURLAsset(url: url)
    let tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
    guard !tracks.isEmpty else { throw .unreadable(name) }
    guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
      throw .failed(name)
    }
    session.shouldOptimizeForNetworkUse = true
    let target = outputs.next(stem: stem(of: url) + " (small)", ext: "mp4")

    let states = session.states(updateInterval: 0.1)
    async let finished: Void = session.export(to: target, as: .mp4)
    for await state in states {
      if case .exporting(let exportProgress) = state {
        progress((Double(index) + exportProgress.fractionCompleted) / Double(inputs.count))
      }
    }
    do { try await finished } catch { throw .failed(name) }
    progress(Double(index + 1) / Double(inputs.count))
  }
}
