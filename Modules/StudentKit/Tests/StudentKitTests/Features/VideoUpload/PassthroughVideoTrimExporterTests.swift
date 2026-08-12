import AVFoundation
import CoreMedia
import Testing

@testable import StudentKit

@Test func passthroughTrimExportsRequestedRangeWithoutReencoding() async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 180, sourceBitRate: 600_000, highEntropy: true)
  )
  defer { fixture.remove() }
  var selection = VideoTrimSelection(sourceDurationSeconds: 6, maxDurationSeconds: 2)
  selection.moveStart(to: 1)
  selection.moveEnd(to: 3)

  let outputURL = try await PassthroughVideoTrimExporter().export(
    sourceURL: fixture.sourceURL,
    selection: selection
  )
  defer { try? FileManager.default.removeItem(at: outputURL) }

  let sourceTrack = try #require(
    try await AVURLAsset(url: fixture.sourceURL).loadTracks(withMediaType: .video).first
  )
  let outputAsset = AVURLAsset(url: outputURL)
  let outputTrack = try #require(
    try await outputAsset.loadTracks(withMediaType: .video).first
  )
  let outputDuration = try await outputAsset.load(.duration).seconds
  let sourceDescriptions = try await sourceTrack.load(.formatDescriptions)
  let outputDescriptions = try await outputTrack.load(.formatDescriptions)
  let sourceCodec = try #require(sourceDescriptions.first.map(CMFormatDescriptionGetMediaSubType))
  let outputCodec = try #require(outputDescriptions.first.map(CMFormatDescriptionGetMediaSubType))
  let sourceDataRate = Double(try await sourceTrack.load(.estimatedDataRate))
  let outputDataRate = Double(try await outputTrack.load(.estimatedDataRate))
  let sourcePayloads = Set(
    try await compressedSampleFingerprints(at: fixture.sourceURL, mediaType: .video)
      .map(\.payloadSHA256)
  )
  let outputPayloads = try await compressedSampleFingerprints(at: outputURL, mediaType: .video)
    .map(\.payloadSHA256)

  #expect(abs(outputDuration - selection.durationSeconds) < 0.15)
  #expect(outputCodec == sourceCodec)
  #expect(outputDataRate > sourceDataRate * 0.7)
  #expect(outputDataRate < sourceDataRate * 1.3)
  #expect(!outputPayloads.isEmpty)
  #expect(outputPayloads.allSatisfy(sourcePayloads.contains))
}

@Test func passthroughTrimKeepsOnlySamplesFromTheSelectedRange() async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 180, sourceBitRate: 600_000, highEntropy: true)
  )
  defer { fixture.remove() }
  var selection = VideoTrimSelection(sourceDurationSeconds: 6, maxDurationSeconds: 2)
  selection.moveStart(to: 2)
  selection.moveEnd(to: 4)

  let outputURL = try await PassthroughVideoTrimExporter().export(
    sourceURL: fixture.sourceURL,
    selection: selection
  )
  defer { try? FileManager.default.removeItem(at: outputURL) }

  let sourceSamples = try await compressedSampleFingerprints(
    at: fixture.sourceURL,
    mediaType: .video
  )
  let outputPayloads = Set(
    try await compressedSampleFingerprints(at: outputURL, mediaType: .video)
      .map(\.payloadSHA256)
  )
  // Anything comfortably outside the selection must be absent: matching the
  // source alone would also pass for a wrong-but-equal-length range.
  let headPayloads = Set(
    sourceSamples.filter { $0.presentationTimeStamp.seconds < 1 }.map(\.payloadSHA256)
  )
  let tailPayloads = Set(
    sourceSamples.filter { $0.presentationTimeStamp.seconds > 5 }.map(\.payloadSHA256)
  )
  let selectedPayloads = Set(
    sourceSamples
      .filter { (1.5...4.5).contains($0.presentationTimeStamp.seconds) }
      .map(\.payloadSHA256)
  )

  #expect(!outputPayloads.isEmpty)
  #expect(outputPayloads.isDisjoint(with: headPayloads))
  #expect(outputPayloads.isDisjoint(with: tailPayloads))
  #expect(outputPayloads.allSatisfy(selectedPayloads.contains))
}

@Test func passthroughTrimOfAShortSourceKeepsTheWholeClip() async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 60, sourceBitRate: 600_000, highEntropy: true)
  )
  defer { fixture.remove() }
  let selection = VideoTrimSelection(sourceDurationSeconds: 2, maxDurationSeconds: 120)

  let outputURL = try await PassthroughVideoTrimExporter().export(
    sourceURL: fixture.sourceURL,
    selection: selection
  )
  defer { try? FileManager.default.removeItem(at: outputURL) }

  let sourceDuration = try await AVURLAsset(url: fixture.sourceURL).load(.duration).seconds
  let outputDuration = try await AVURLAsset(url: outputURL).load(.duration).seconds

  #expect(selection.startSeconds == 0)
  #expect(abs(outputDuration - sourceDuration) < 0.15)
}

// Kept to the same 30-frame budget as the other audio fixtures: a longer
// high-entropy source here starves the encoder when the audio tests run in
// parallel and wedges the whole suite.
@Test func passthroughTrimKeepsTheAudioTrack() async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 30, audioChannelCount: 1)
  )
  defer { fixture.remove() }
  var selection = VideoTrimSelection(sourceDurationSeconds: 1, maxDurationSeconds: 1)
  selection.moveStart(to: 0.2)
  selection.moveEnd(to: 0.8)

  let outputURL = try await PassthroughVideoTrimExporter().export(
    sourceURL: fixture.sourceURL,
    selection: selection
  )
  defer { try? FileManager.default.removeItem(at: outputURL) }

  let outputAudioTracks = try await AVURLAsset(url: outputURL).loadTracks(withMediaType: .audio)
  let audioPayloads = try await compressedSampleFingerprints(at: outputURL, mediaType: .audio)

  #expect(outputAudioTracks.count == 1)
  #expect(!audioPayloads.isEmpty)
}

/// The recorder stops one frame *past* the cap, so a full-length recording is
/// clamped by the selection to exactly `maxDurationSeconds` — and `enqueue`
/// rejects anything longer than the cap outright ("视频超过 120 秒上限").
/// A passthrough export that overshot its range by even a few milliseconds
/// would therefore make a just-recorded video unsendable, so pin the contract.
@Test func passthroughTrimOutputNeverOvershootsTheSelectionCap() async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 60, sourceBitRate: 600_000, highEntropy: true)
  )
  defer { fixture.remove() }
  var selection = VideoTrimSelection(sourceDurationSeconds: 2, maxDurationSeconds: 1)
  selection.moveEnd(to: 1)

  let outputURL = try await PassthroughVideoTrimExporter().export(
    sourceURL: fixture.sourceURL,
    selection: selection
  )
  defer { try? FileManager.default.removeItem(at: outputURL) }
  let outputDuration = try await AVURLAsset(url: outputURL).load(.duration).seconds

  #expect(selection.durationSeconds == selection.maxDurationSeconds)
  #expect(outputDuration <= selection.maxDurationSeconds)
}
