import AVFoundation
import Foundation

/// Live `VideoExporting` backed by `AVAssetExportSession`.
///
/// Spec 027 wants client-side H.264: the 1080p preset re-encodes camera/photo
/// library footage (typically HEVC) to H.264 .mp4 at a medium bitrate.
/// Bitrate is best-effort — `AVAssetExportSession` exposes no explicit rate
/// control (spec 027 §VideoTranscoder note).
public struct AVFoundationVideoExporter: VideoExporting {
  public init() {}

  public func durationSeconds(of sourceURL: URL) async throws -> Double {
    let asset = AVURLAsset(url: sourceURL)
    let duration = try await asset.load(.duration)
    return duration.seconds
  }

  public func export(from sourceURL: URL, to destinationURL: URL) async throws {
    let asset = AVURLAsset(url: sourceURL)
    guard
      let session = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPreset1920x1080
      )
    else {
      throw VideoUploadError.exportFailed("AVAssetExportSession unavailable for preset 1080p")
    }

    try? FileManager.default.removeItem(at: destinationURL)
    session.outputURL = destinationURL
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      session.exportAsynchronously {
        continuation.resume()
      }
    }

    guard session.status == .completed else {
      let reason = session.error?.localizedDescription ?? "status \(session.status.rawValue)"
      throw VideoUploadError.exportFailed(reason)
    }
  }
}
