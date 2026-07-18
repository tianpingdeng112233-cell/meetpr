struct VideoDimensions: Equatable, Sendable {
  let width: Double
  let height: Double
}

struct VideoTransform: Equatable, Sendable {
  let horizontalScale: Double
  let verticalShear: Double
  let horizontalShear: Double
  let verticalScale: Double

  static let identity = VideoTransform(
    horizontalScale: 1,
    verticalShear: 0,
    horizontalShear: 0,
    verticalScale: 1
  )
}

/// Platform-neutral export decision. Translation does not affect the rendered
/// dimensions, so only the linear portion of `preferredTransform` is needed.
enum VideoPassthroughEligibility {
  static let h264CodecFourCC: UInt32 = 0x6176_6331  // "avc1"

  static func shouldPassthrough(
    codecFourCC: UInt32?,
    naturalSize: VideoDimensions,
    preferredTransform: VideoTransform = .identity
  ) -> Bool {
    guard codecFourCC == h264CodecFourCC else { return false }
    guard naturalSize.width.isFinite, naturalSize.height.isFinite else { return false }
    guard naturalSize.width > 0, naturalSize.height > 0 else { return false }

    let displayedWidth =
      abs(preferredTransform.horizontalScale * naturalSize.width)
      + abs(preferredTransform.horizontalShear * naturalSize.height)
    let displayedHeight =
      abs(preferredTransform.verticalShear * naturalSize.width)
      + abs(preferredTransform.verticalScale * naturalSize.height)

    guard displayedWidth.isFinite, displayedHeight.isFinite else { return false }
    guard displayedWidth > 0, displayedHeight > 0 else { return false }

    let longEdge = max(displayedWidth, displayedHeight)
    let shortEdge = min(displayedWidth, displayedHeight)
    return longEdge <= 1_920 && shortEdge <= 1_080
  }
}

/// Platform-neutral passthrough-first orchestration: try remux when eligible,
/// fall back to the transcode preset exactly once on non-cancellation failure.
enum VideoExportStrategy {
  static func run(
    passthroughEligible: Bool,
    passthroughPreset: String,
    transcodePreset: String,
    export: (String) async throws -> Void
  ) async throws {
    if passthroughEligible {
      do {
        try await export(passthroughPreset)
        return
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        // A source can have compatible H.264 video but incompatible audio or
        // container details. Retry once through the established transcode path.
      }
    }
    try await export(transcodePreset)
  }
}
