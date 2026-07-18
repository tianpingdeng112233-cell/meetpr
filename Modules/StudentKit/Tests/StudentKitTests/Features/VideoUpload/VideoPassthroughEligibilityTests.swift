import Testing

@testable import StudentKit

private let h264FourCC: UInt32 = 0x6176_6331
private let hevcFourCC: UInt32 = 0x6876_6331

@Test("H.264 at the exact 1080p boundary uses passthrough")
func h264At1080pUsesPassthrough() {
  #expect(
    VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080)
    )
  )
}

@Test("HEVC at 1080p uses transcoding")
func hevcAt1080pUsesTranscoding() {
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: hevcFourCC,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080)
    )
  )
}

@Test("H.264 at 4K uses transcoding")
func h264At4KUsesTranscoding() {
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 3_840, height: 2_160)
    )
  )
}

@Test("Landscape preferred transform stays within the 1080p boundary")
func landscapeTransformUsesPassthrough() {
  let landscapeTransform = VideoTransform(
    horizontalScale: -1,
    verticalShear: 0,
    horizontalShear: 0,
    verticalScale: -1
  )

  #expect(
    VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080),
      preferredTransform: landscapeTransform
    )
  )
}

@Test("Portrait preferred transform swaps the rendered dimensions")
func portraitTransformUsesPassthrough() {
  let portraitTransform = VideoTransform(
    horizontalScale: 0,
    verticalShear: 1,
    horizontalShear: -1,
    verticalScale: 0
  )

  #expect(
    VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080),
      preferredTransform: portraitTransform
    )
  )
}

@Test("Unknown codec uses transcoding")
func unknownCodecUsesTranscoding() {
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: nil,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080)
    )
  )
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: 0x3F3F_3F3F,
      naturalSize: VideoDimensions(width: 1_920, height: 1_080)
    )
  )
}

@Test("Either rendered edge exceeding the 1080p boundary uses transcoding")
func renderedEdgeOverBoundaryUsesTranscoding() {
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 1_921, height: 1_080)
    )
  )
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 1_920, height: 1_081)
    )
  )
}

@Test("Invalid dimensions use transcoding")
func invalidDimensionsUseTranscoding() {
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: 0, height: 1_080)
    )
  )
  #expect(
    !VideoPassthroughEligibility.shouldPassthrough(
      codecFourCC: h264FourCC,
      naturalSize: VideoDimensions(width: .infinity, height: 1_080)
    )
  )
}

@Test func strategyFallsBackToTranscodeExactlyOnceOnPassthroughFailure() async throws {
  struct RemuxError: Error {}
  var presets: [String] = []
  try await VideoExportStrategy.run(
    passthroughEligible: true, passthroughPreset: "pass", transcodePreset: "1080",
    export: { preset in
      presets.append(preset)
      if preset == "pass" { throw RemuxError() }
    }
  )
  #expect(presets == ["pass", "1080"])
}

@Test func strategyDoesNotFallBackWhenPassthroughIsCancelled() async {
  var presets: [String] = []
  await #expect(throws: CancellationError.self) {
    try await VideoExportStrategy.run(
      passthroughEligible: true, passthroughPreset: "pass", transcodePreset: "1080",
      export: { preset in
        presets.append(preset)
        throw CancellationError()
      }
    )
  }
  #expect(presets == ["pass"])
}

@Test func strategyRunsPassthroughOnlyOnSuccessAndTranscodeOnlyWhenIneligible() async throws {
  var presets: [String] = []
  try await VideoExportStrategy.run(
    passthroughEligible: true, passthroughPreset: "pass", transcodePreset: "1080",
    export: { presets.append($0) }
  )
  try await VideoExportStrategy.run(
    passthroughEligible: false, passthroughPreset: "pass", transcodePreset: "1080",
    export: { presets.append($0) }
  )
  #expect(presets == ["pass", "1080"])
}
