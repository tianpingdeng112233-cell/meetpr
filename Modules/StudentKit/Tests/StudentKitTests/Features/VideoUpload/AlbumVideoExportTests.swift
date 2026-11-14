import AVFoundation
import CoreMedia
import Foundation
import Testing

@testable import StudentKit

@Test("Album export keeps only the largest enabled video track")
func albumExportSelectsMainTrack() async throws {
  let small = try await VideoExportFixture.make(.init(frameCount: 10))
  defer { small.remove() }
  let large = try await VideoExportFixture.make(.init(frameCount: 10, width: 640, height: 360))
  defer { large.remove() }
  let composition = AVMutableComposition()
  for fixture in [small, large] {
    let asset = AVURLAsset(url: fixture.sourceURL)
    let source = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let track = try #require(
      composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    )
    try track.insertTimeRange(try await source.load(.timeRange), of: source, at: .zero)
  }
  let combined = small.directory.appending(path: "two-tracks.mov")
  let session = try #require(
    AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
  )
  session.outputURL = combined
  session.outputFileType = .mov
  await session.export()
  #expect(session.status == .completed)
  let sourceTracks = try await AVURLAsset(url: combined).loadTracks(withMediaType: .video)
  #expect(sourceTracks.count == 2)

  try await AVFoundationVideoExporter().export(from: combined, to: small.outputURL)

  let tracks = try await AVURLAsset(url: small.outputURL).loadTracks(withMediaType: .video)
  #expect(tracks.count == 1)
  let track = try #require(tracks.first)
  #expect(try await track.load(.naturalSize) == CGSize(width: 640, height: 360))
}

@Test("10-bit HLG album source exports H.264 with all three BT.709 color tags")
func albumHDRExportConvertsToSDR() async throws {
  let fixture = try await HDRVideoExportFixture.make()
  defer { fixture.remove() }
  let source = try #require(
    try await AVURLAsset(url: fixture.sourceURL).loadTracks(withMediaType: .video).first)
  let sourceFormat = try #require(try await source.load(.formatDescriptions).first)
  #expect(CMFormatDescriptionGetMediaSubType(sourceFormat) == kCMVideoCodecType_HEVC)
  #expect(
    CMFormatDescriptionGetExtension(
      sourceFormat, extensionKey: kCMFormatDescriptionExtension_TransferFunction)
      as? String == "ITU_R_2100_HLG")

  try await AVFoundationVideoExporter().export(from: fixture.sourceURL, to: fixture.outputURL)

  let track = try #require(
    try await AVURLAsset(url: fixture.outputURL).loadTracks(withMediaType: .video).first)
  let format = try #require(try await track.load(.formatDescriptions).first)
  #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_H264)
  for key in [
    kCMFormatDescriptionExtension_ColorPrimaries,
    kCMFormatDescriptionExtension_TransferFunction,
    kCMFormatDescriptionExtension_YCbCrMatrix,
  ] {
    #expect(CMFormatDescriptionGetExtension(format, extensionKey: key) as? String == "ITU_R_709_2")
  }
}
