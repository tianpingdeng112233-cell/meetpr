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

struct VideoTrackExportProperties: Equatable, Sendable {
  let codecFourCCs: [UInt32]
  let naturalSize: VideoDimensions
  let preferredTransform: VideoTransform
  let estimatedDataRate: Double
}

struct AudioTrackExportProperties: Equatable, Sendable {
  let codecFourCCs: [UInt32]
  let estimatedDataRate: Double
}

enum VideoExportDecision: Equatable, Sendable {
  case passthrough
  case transcode
}

/// Platform-neutral export decision used by the AVFoundation implementation
/// and by the macOS host test suite.
enum VideoPassthroughEligibility {
  static let h264CodecFourCC: UInt32 = 0x6176_6331  // "avc1"
  static let aacCodecFourCC: UInt32 = 0x6161_6320  // "aac "
  static let maximumLongEdge = 1_280.0
  static let maximumVideoDataRate = 3_500_000.0
  static let maximumAudioDataRate = 128_000.0

  static func decision(
    video: VideoTrackExportProperties,
    audio: AudioTrackExportProperties?
  ) -> VideoExportDecision {
    guard !video.codecFourCCs.isEmpty else { return .transcode }
    guard video.codecFourCCs.allSatisfy({ $0 == h264CodecFourCC }) else { return .transcode }
    guard isPositiveFinite(video.estimatedDataRate) else { return .transcode }
    guard video.estimatedDataRate <= maximumVideoDataRate else { return .transcode }
    guard renderedLongEdge(video) <= maximumLongEdge else { return .transcode }

    if let audio {
      guard !audio.codecFourCCs.isEmpty else { return .transcode }
      guard audio.codecFourCCs.allSatisfy({ $0 == aacCodecFourCC }) else { return .transcode }
      guard isPositiveFinite(audio.estimatedDataRate) else { return .transcode }
      guard audio.estimatedDataRate <= maximumAudioDataRate else { return .transcode }
    }
    return .passthrough
  }

  private static func renderedLongEdge(_ video: VideoTrackExportProperties) -> Double {
    let width = video.naturalSize.width
    let height = video.naturalSize.height
    guard width.isFinite, height.isFinite, width > 0, height > 0 else {
      return .infinity
    }

    let transform = video.preferredTransform
    let displayedWidth =
      abs(transform.horizontalScale * width) + abs(transform.horizontalShear * height)
    let displayedHeight =
      abs(transform.verticalShear * width) + abs(transform.verticalScale * height)
    guard
      displayedWidth.isFinite,
      displayedHeight.isFinite,
      displayedWidth > 0,
      displayedHeight > 0
    else {
      return .infinity
    }
    return max(displayedWidth, displayedHeight)
  }

  private static func isPositiveFinite(_ value: Double) -> Bool {
    value.isFinite && value > 0
  }
}

/// Tries a compressed-sample remux first when eligible, then retries once
/// through the established transcode path on any non-cancellation failure.
enum VideoExportStrategy {
  static func run(
    initialDecision: VideoExportDecision,
    export: (VideoExportDecision) async throws -> Void
  ) async throws {
    guard initialDecision == .passthrough else {
      try await export(.transcode)
      return
    }

    do {
      try await export(.passthrough)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      try await export(.transcode)
    }
  }
}
