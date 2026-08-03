import Testing

@testable import StudentKit

private let h264FourCC = VideoPassthroughEligibility.h264CodecFourCC
private let aacFourCC = VideoPassthroughEligibility.aacCodecFourCC
private let hevcFourCC: UInt32 = 0x6876_6331
private let pcmFourCC: UInt32 = 0x6C70_636D

@Test("Eligible H.264 video without audio uses passthrough")
func eligibleSilentVideoUsesPassthrough() {
  #expect(decision() == .passthrough)
}

@Test("Video bitrate boundary is inclusive")
func videoBitrateBoundaryIsInclusive() {
  #expect(decision(videoDataRate: 3_500_000) == .passthrough)
  #expect(decision(videoDataRate: 3_500_000.001) == .transcode)
}

@Test("Unknown, non-positive, or non-finite video bitrate transcodes")
func invalidVideoBitratesTranscode() {
  #expect(decision(videoDataRate: 0) == .transcode)
  #expect(decision(videoDataRate: -1) == .transcode)
  #expect(decision(videoDataRate: .nan) == .transcode)
  #expect(decision(videoDataRate: .infinity) == .transcode)
}

@Test("Rendered long-edge boundary is inclusive in landscape and portrait")
func renderedLongEdgeBoundaryIsInclusive() {
  #expect(decision(width: 1_280, height: 720) == .passthrough)
  #expect(decision(width: 1_280.001, height: 720) == .transcode)

  let portraitTransform = VideoTransform(
    horizontalScale: 0,
    verticalShear: 1,
    horizontalShear: -1,
    verticalScale: 0
  )
  #expect(
    decision(width: 1_280, height: 720, transform: portraitTransform) == .passthrough
  )
  #expect(
    decision(width: 1_280.001, height: 720, transform: portraitTransform) == .transcode
  )
}

@Test("Invalid source geometry transcodes")
func invalidSourceGeometryTranscodes() {
  #expect(decision(width: 0) == .transcode)
  #expect(decision(height: -1) == .transcode)
  #expect(decision(width: .nan) == .transcode)
  #expect(decision(height: .infinity) == .transcode)

  let invalidTransform = VideoTransform(
    horizontalScale: .nan,
    verticalShear: 0,
    horizontalShear: 0,
    verticalScale: 1
  )
  #expect(decision(transform: invalidTransform) == .transcode)
}

@Test("Only a known H.264 video codec can passthrough")
func onlyH264VideoCanPassthrough() {
  #expect(decision(videoCodecs: [h264FourCC]) == .passthrough)
  #expect(decision(videoCodecs: [hevcFourCC]) == .transcode)
  #expect(decision(videoCodecs: []) == .transcode)
}

@Test("Every video format description must be H.264")
func everyVideoDescriptionMustBeH264() {
  #expect(decision(videoCodecs: [h264FourCC, h264FourCC]) == .passthrough)
  #expect(decision(videoCodecs: [h264FourCC, hevcFourCC]) == .transcode)
}

@Test("AAC audio bitrate boundary is inclusive")
func audioBitrateBoundaryIsInclusive() {
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC], estimatedDataRate: 128_000))
      == .passthrough
  )
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC], estimatedDataRate: 128_000.001))
      == .transcode
  )
}

@Test("Audio must be known, positive-rate AAC")
func incompatibleAudioTranscodes() {
  #expect(
    decision(audio: .init(codecFourCCs: [pcmFourCC], estimatedDataRate: 96_000)) == .transcode
  )
  #expect(decision(audio: .init(codecFourCCs: [], estimatedDataRate: 96_000)) == .transcode)
  #expect(decision(audio: .init(codecFourCCs: [aacFourCC], estimatedDataRate: 0)) == .transcode)
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC], estimatedDataRate: .nan)) == .transcode
  )
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC], estimatedDataRate: .infinity))
      == .transcode
  )
}

@Test("Every audio format description must be AAC")
func everyAudioDescriptionMustBeAAC() {
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC, aacFourCC], estimatedDataRate: 96_000))
      == .passthrough
  )
  #expect(
    decision(audio: .init(codecFourCCs: [aacFourCC, pcmFourCC], estimatedDataRate: 96_000))
      == .transcode
  )
}

@Test("Passthrough failure retries through a fresh transcode attempt")
func passthroughFailureRetriesTranscode() async throws {
  var attempts: [VideoExportDecision] = []

  try await VideoExportStrategy.run(initialDecision: .passthrough) { decision in
    attempts.append(decision)
    if decision == .passthrough {
      throw ExportStrategyTestError.passthroughRejected
    }
  }

  #expect(attempts == [.passthrough, .transcode])
}

@Test("Passthrough cancellation never starts a transcode retry")
func passthroughCancellationDoesNotRetry() async {
  var attempts: [VideoExportDecision] = []

  await #expect(throws: CancellationError.self) {
    try await VideoExportStrategy.run(initialDecision: .passthrough) { decision in
      attempts.append(decision)
      throw CancellationError()
    }
  }

  #expect(attempts == [.passthrough])
}

@Test("Ineligible source starts directly on the transcode path")
func ineligibleSourceTranscodesOnce() async throws {
  var attempts: [VideoExportDecision] = []

  try await VideoExportStrategy.run(initialDecision: .transcode) { decision in
    attempts.append(decision)
  }

  #expect(attempts == [.transcode])
}

private func decision(
  videoCodecs: [UInt32] = [h264FourCC],
  width: Double = 1_280,
  height: Double = 720,
  transform: VideoTransform = .identity,
  videoDataRate: Double = 3_500_000,
  audio: AudioTrackExportProperties? = nil
) -> VideoExportDecision {
  VideoPassthroughEligibility.decision(
    video: VideoTrackExportProperties(
      codecFourCCs: videoCodecs,
      naturalSize: VideoDimensions(width: width, height: height),
      preferredTransform: transform,
      estimatedDataRate: videoDataRate
    ),
    audio: audio
  )
}

private enum ExportStrategyTestError: Error {
  case passthroughRejected
}
