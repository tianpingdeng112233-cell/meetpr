import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Testing

@testable import StudentKit

@Test("Video export produces a readable, fast-start H.264 MP4 without upscaling")
func videoExportProducesReadableFastStartMP4() async throws {
  let fixture = try await VideoExportFixture.make(.init(frameCount: 30))
  defer { fixture.remove() }

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let attributes = try FileManager.default.attributesOfItem(atPath: fixture.outputURL.path)
  #expect((attributes[.size] as? NSNumber)?.intValue ?? 0 > 0)

  let outputAsset = AVURLAsset(url: fixture.outputURL)
  let duration = try await outputAsset.load(.duration)
  #expect(duration.seconds > 0.9)

  let tracks = try await outputAsset.loadTracks(withMediaType: .video)
  let outputTrack = try #require(tracks.first)
  let naturalSize = try await outputTrack.load(.naturalSize)
  #expect(naturalSize == CGSize(width: 320, height: 180))
  let descriptions = try await outputTrack.load(.formatDescriptions)
  let formatDescription = try #require(descriptions.first)
  #expect(CMFormatDescriptionGetMediaSubType(formatDescription) == kCMVideoCodecType_H264)

  let outputData = try Data(contentsOf: fixture.outputURL)
  let moovRange = try #require(outputData.range(of: Data("moov".utf8)))
  let mdatRange = try #require(outputData.range(of: Data("mdat".utf8)))
  #expect(moovRange.lowerBound < mdatRange.lowerBound)
}

@Test("Video export preserves the full portrait preferred transform")
func videoExportPreservesPortraitTransform() async throws {
  let portraitTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 30, preferredTransform: portraitTransform)
  )
  defer { fixture.remove() }

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let outputAsset = AVURLAsset(url: fixture.outputURL)
  let tracks = try await outputAsset.loadTracks(withMediaType: .video)
  let outputTrack = try #require(tracks.first)
  let naturalSize = try await outputTrack.load(.naturalSize)
  let transform = try await outputTrack.load(.preferredTransform)

  // No downscale (long edge 320 ≤ 1280): the transform round-trips verbatim,
  // translation included — CGSize.applying alone would miss a broken tx/ty.
  #expect(naturalSize == CGSize(width: 320, height: 180))
  expectTransformsMatch(transform, portraitTransform)
}

@Test("Downscaled portrait export rescales the transform translation")
func downscaledPortraitExportRescalesTransformTranslation() async throws {
  let portraitTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1_080, ty: 0)
  let fixture = try await VideoExportFixture.make(
    .init(
      frameCount: 10,
      preferredTransform: portraitTransform,
      width: 1_920,
      height: 1_080
    )
  )
  defer { fixture.remove() }

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let outputAsset = AVURLAsset(url: fixture.outputURL)
  let tracks = try await outputAsset.loadTracks(withMediaType: .video)
  let outputTrack = try #require(tracks.first)
  let naturalSize = try await outputTrack.load(.naturalSize)
  let transform = try await outputTrack.load(.preferredTransform)

  // 1920x1080 rotated portrait → encoded 1280x720; tx must scale with the
  // dimensions (1080 × 2/3 = 720) or players letterbox/offset the video.
  #expect(naturalSize == CGSize(width: 1_280, height: 720))
  expectTransformsMatch(transform, CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 720, ty: 0))
  let renderedSize = naturalSize.applying(transform)
  #expect(abs(renderedSize.width) == 720)
  #expect(abs(renderedSize.height) == 1_280)
}

@Test("High-bitrate 1080p export caps dimensions and bitrate without resampling frames")
func highBitrate1080pExportMeetsDeliveryBudget() async throws {
  // High-entropy frames at a realistic frame rate: flat fills compress so well
  // that the source would already sit under the target and the cap assertion
  // would pass even with the limiter removed.
  let fixture = try await VideoExportFixture.make(
    .init(
      frameCount: 90,
      width: 1_920,
      height: 1_080,
      frameRate: 30,
      sourceBitRate: 12_000_000,
      highEntropy: true
    )
  )
  defer { fixture.remove() }

  let sourceAsset = AVURLAsset(url: fixture.sourceURL)
  let sourceTracks = try await sourceAsset.loadTracks(withMediaType: .video)
  let sourceTrack = try #require(sourceTracks.first)
  let sourceDataRate = try await sourceTrack.load(.estimatedDataRate)
  #expect(sourceDataRate > 3_500_000, "fixture must exceed the target for the cap to be provable")

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let outputAsset = AVURLAsset(url: fixture.outputURL)
  let duration = try await outputAsset.load(.duration)
  #expect(duration.seconds >= 2.9)
  let tracks = try await outputAsset.loadTracks(withMediaType: .video)
  let outputTrack = try #require(tracks.first)
  let naturalSize = try await outputTrack.load(.naturalSize)
  let estimatedDataRate = try await outputTrack.load(.estimatedDataRate)
  let nominalFrameRate = try await outputTrack.load(.nominalFrameRate)

  #expect(naturalSize == CGSize(width: 1_280, height: 720))
  #expect(estimatedDataRate <= 3_500_000)
  #expect(abs(nominalFrameRate - 30) < 0.5)
}

@Test("Video export transcodes source audio to AAC", arguments: [1, 2])
func videoExportTranscodesSourceAudioToAAC(channelCount: Int) async throws {
  let fixture = try await VideoExportFixture.make(
    .init(frameCount: 30, audioChannelCount: channelCount)
  )
  defer { fixture.remove() }

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let outputAsset = AVURLAsset(url: fixture.outputURL)
  let duration = try await outputAsset.load(.duration)
  #expect(duration.seconds > 0.9)
  #expect(try await outputAsset.load(.isPlayable))

  let audioTracks = try await outputAsset.loadTracks(withMediaType: .audio)
  #expect(audioTracks.count == 1)
  let audioTrack = try #require(audioTracks.first)
  let audioDuration = try await audioTrack.load(.timeRange).duration
  #expect(audioDuration.seconds > 0.9)
  let descriptions = try await audioTrack.load(.formatDescriptions)
  let formatDescription = try #require(descriptions.first)
  #expect(CMFormatDescriptionGetMediaSubType(formatDescription) == kAudioFormatMPEG4AAC)
  let basicDescription = try #require(
    CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
  )
  #expect(basicDescription.pointee.mChannelsPerFrame == UInt32(channelCount))
}

@Test("Cancelling video export removes its partial output")
func cancellingVideoExportRemovesPartialOutput() async throws {
  let fixture = try await VideoExportFixture.make(.init(frameCount: 600))
  defer { fixture.remove() }

  let exportTask = Task {
    try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)
  }
  let partialOutputAppeared = await waitForFile(at: fixture.outputURL)
  #expect(partialOutputAppeared)
  exportTask.cancel()

  await #expect(throws: CancellationError.self) {
    try await exportTask.value
  }
  #expect(!FileManager.default.fileExists(atPath: fixture.outputURL.path))
}

@Test("A cancel that races the finishWriting success still resolves as cancellation")
func cancelRacingFinishWritingSuccessResolvesAsCancellation() {
  // Deterministic coverage of the race window: cancel() marks the flag while a
  // concurrent finishWriting callback delivers .success — the committed final
  // state must be cancellation so the partial file gets deleted.
  let cancelledSuccess = AssetWriterCoordinator.finalResult(.success(()), isCancelled: true)
  guard case .failure(let error) = cancelledSuccess else {
    Issue.record("Expected a cancelled success to resolve as failure")
    return
  }
  #expect(error is CancellationError)

  let underlying = VideoUploadError.exportFailed("writer failed")
  let cancelledFailure = AssetWriterCoordinator.finalResult(
    .failure(underlying),
    isCancelled: true
  )
  guard case .failure(let preserved) = cancelledFailure else {
    Issue.record("Expected a cancelled failure to stay a failure")
    return
  }
  #expect(preserved as? VideoUploadError == underlying)

  let plainSuccess = AssetWriterCoordinator.finalResult(.success(()), isCancelled: false)
  guard case .success = plainSuccess else {
    Issue.record("Expected an uncancelled success to stay a success")
    return
  }
}

@Test("Invalid source errors retain the underlying reason and remove output")
func invalidSourceReportsExportFailureAndRemovesOutput() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let sourceURL = directory.appending(path: "invalid.mov")
  let outputURL = directory.appending(path: "output.mp4")
  try Data("not a movie".utf8).write(to: sourceURL)

  do {
    try await AVFoundationVideoExporter().export(from: sourceURL, to: outputURL)
    Issue.record("Expected export to fail")
  } catch let VideoUploadError.exportFailed(reason) {
    #expect(!reason.isEmpty)
  } catch {
    Issue.record("Unexpected error: \(error)")
  }
  #expect(!FileManager.default.fileExists(atPath: outputURL.path))
}

private func expectTransformsMatch(
  _ transform: CGAffineTransform,
  _ expected: CGAffineTransform
) {
  #expect(abs(transform.a - expected.a) < 0.001)
  #expect(abs(transform.b - expected.b) < 0.001)
  #expect(abs(transform.c - expected.c) < 0.001)
  #expect(abs(transform.d - expected.d) < 0.001)
  #expect(abs(transform.tx - expected.tx) < 0.001)
  #expect(abs(transform.ty - expected.ty) < 0.001)
}

private func waitForFile(at url: URL) async -> Bool {
  for _ in 0..<1_000 {
    if FileManager.default.fileExists(atPath: url.path) { return true }
    try? await Task.sleep(for: .milliseconds(1))
  }
  return false
}
