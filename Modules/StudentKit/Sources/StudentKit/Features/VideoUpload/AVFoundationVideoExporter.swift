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

    // Cooperative cancellation: cancelling the surrounding Task cancels the
    // export session, and any partial output is removed below (Codex P1/P2).
    let box = ExportSessionBox(session)
    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        box.session.exportAsynchronously {
          continuation.resume()
        }
      }
    } onCancel: {
      box.session.cancelExport()
    }

    guard session.status == .completed else {
      try? FileManager.default.removeItem(at: destinationURL)
      if session.status == .cancelled || Task.isCancelled {
        throw CancellationError()
      }
      let reason = session.error?.localizedDescription ?? "status \(session.status.rawValue)"
      throw VideoUploadError.exportFailed(reason)
    }
  }
}

/// AVAssetExportSession is thread-safe for cancelExport but not Sendable;
/// the box scopes the unchecked crossing to this one cancellation hop.
private final class ExportSessionBox: @unchecked Sendable {
  let session: AVAssetExportSession
  init(_ session: AVAssetExportSession) { self.session = session }
}
