import AVFoundation
import CoreMedia
import Foundation

/// Live `VideoExporting` backed by `AVAssetExportSession`.
///
/// H.264 sources at or below 1080p are remuxed into MP4 without re-encoding.
/// Other sources retain spec 027's 1080p H.264 re-encoding path.
///
/// Deliberate trade-off (David 2026-07-18): remuxed uploads keep the source
/// bitrate (camera captures ≈15 Mbps vs ≈10 Mbps re-encoded), spending some
/// extra upload bytes to skip a transcode that ran at roughly clip duration
/// and to preserve quality bit-for-bit.
public struct AVFoundationVideoExporter: VideoExporting {
  public init() {}

  public func durationSeconds(of sourceURL: URL) async throws -> Double {
    let asset = AVURLAsset(url: sourceURL)
    let duration = try await asset.load(.duration)
    return duration.seconds
  }

  public func export(from sourceURL: URL, to destinationURL: URL) async throws {
    let asset = AVURLAsset(url: sourceURL)

    try await VideoExportStrategy.run(
      passthroughEligible: try await isPassthroughEligible(asset),
      passthroughPreset: AVAssetExportPresetPassthrough,
      transcodePreset: AVAssetExportPreset1920x1080,
      export: { preset in
        try await self.export(asset, presetName: preset, destinationURL: destinationURL)
      }
    )
  }

  private func isPassthroughEligible(_ asset: AVAsset) async throws -> Bool {
    do {
      let videoTracks = try await asset.loadTracks(withMediaType: .video)
      guard videoTracks.count == 1, let track = videoTracks.first else {
        return false
      }
      let formatDescriptions = try await track.load(.formatDescriptions)
      guard let formatDescription = formatDescriptions.first else { return false }
      let codecFourCC = CMFormatDescriptionGetMediaSubType(formatDescription)
      guard
        formatDescriptions.allSatisfy({
          CMFormatDescriptionGetMediaSubType($0) == codecFourCC
        })
      else { return false }

      let naturalSize = try await track.load(.naturalSize)
      let preferredTransform = try await track.load(.preferredTransform)
      return VideoPassthroughEligibility.shouldPassthrough(
        codecFourCC: codecFourCC,
        naturalSize: VideoDimensions(
          width: naturalSize.width,
          height: naturalSize.height
        ),
        preferredTransform: VideoTransform(
          horizontalScale: preferredTransform.a,
          verticalShear: preferredTransform.b,
          horizontalShear: preferredTransform.c,
          verticalScale: preferredTransform.d
        )
      )
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      return false
    }
  }

  private func export(
    _ asset: AVAsset,
    presetName: String,
    destinationURL: URL
  ) async throws {
    // Every path through this helper — early cancellation, session-unavailable,
    // export failure — must leave no stale/partial file at the destination.
    try? FileManager.default.removeItem(at: destinationURL)
    var succeeded = false
    defer {
      if !succeeded { try? FileManager.default.removeItem(at: destinationURL) }
    }

    try Task.checkCancellation()
    guard
      let session = AVAssetExportSession(
        asset: asset,
        presetName: presetName
      )
    else {
      throw VideoUploadError.exportFailed(
        "AVAssetExportSession unavailable for preset \(presetName)")
    }

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
      if session.status == .cancelled || Task.isCancelled {
        throw CancellationError()
      }
      let reason = session.error?.localizedDescription ?? "status \(session.status.rawValue)"
      throw VideoUploadError.exportFailed(reason)
    }
    succeeded = true
  }
}

/// AVAssetExportSession is thread-safe for cancelExport but not Sendable;
/// the box scopes the unchecked crossing to this one cancellation hop.
private final class ExportSessionBox: @unchecked Sendable {
  let session: AVAssetExportSession
  init(_ session: AVAssetExportSession) { self.session = session }
}
