import AVFoundation
import CoreMedia
import Foundation
import VideoToolbox

/// Live `VideoExporting` backed by an explicitly configured asset reader and writer.
public struct AVFoundationVideoExporter: VideoExporting {
  private static let maximumRenderedEdge = 1_280.0
  private static let targetVideoBitRate = 2_750_000
  /// Hard ceiling per 1s window. `AVVideoAverageBitRateKey` alone is a soft
  /// target the encoder overshoots ~3x on noise-like content (dim-gym sensor
  /// grain), which would defeat the upload-size goal of spec 065.
  private static let peakVideoBitRate = 3_500_000
  private static let targetAudioBitRate = 96_000

  public init() {}

  public func durationSeconds(of sourceURL: URL) async throws -> Double {
    let asset = AVURLAsset(url: sourceURL)
    let duration = try await asset.load(.duration)
    return duration.seconds
  }

  public func export(from sourceURL: URL, to destinationURL: URL) async throws {
    try? FileManager.default.removeItem(at: destinationURL)
    var succeeded = false
    defer {
      if !succeeded { try? FileManager.default.removeItem(at: destinationURL) }
    }

    do {
      try Task.checkCancellation()
      let asset = AVURLAsset(url: sourceURL)
      let videoTracks = try await asset.loadTracks(withMediaType: .video)
      guard videoTracks.count == 1, let videoTrack = videoTracks.first else {
        throw VideoUploadError.exportFailed("Expected exactly one video track")
      }

      let reader = try AVAssetReader(asset: asset)
      let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
      writer.shouldOptimizeForNetworkUse = true

      let videoStream = try await makeVideoStream(
        track: videoTrack,
        reader: reader,
        writer: writer
      )
      var streams = [videoStream]

      if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
        streams.append(
          try await makeAudioStream(track: audioTrack, reader: reader, writer: writer)
        )
      }

      try Task.checkCancellation()
      let coordinator = AssetWriterCoordinator(reader: reader, writer: writer, streams: streams)
      try await coordinator.run()
      succeeded = true
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as VideoUploadError {
      throw error
    } catch {
      if Task.isCancelled { throw CancellationError() }
      throw VideoUploadError.exportFailed(error.localizedDescription)
    }
  }

  private func makeVideoStream(
    track: AVAssetTrack,
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws -> AssetWriterStream {
    let naturalSize = try await track.load(.naturalSize)
    let preferredTransform = try await track.load(.preferredTransform)
    let estimatedDataRate = try await track.load(.estimatedDataRate)
    let geometry = try Self.outputGeometry(
      naturalSize: naturalSize,
      preferredTransform: preferredTransform
    )
    let bitRate = Self.outputVideoBitRate(sourceBitRate: estimatedDataRate)

    let readerOutput = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
      ]
    )
    readerOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(readerOutput) else {
      throw VideoUploadError.exportFailed("Unable to add the video reader output")
    }
    reader.add(readerOutput)

    let writerInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: geometry.width,
        AVVideoHeightKey: geometry.height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: bitRate,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          kVTCompressionPropertyKey_DataRateLimits as String: [
            Self.peakVideoBitRate / 8, 1,
          ],
        ],
      ]
    )
    writerInput.expectsMediaDataInRealTime = false
    writerInput.transform = geometry.transform
    guard writer.canAdd(writerInput) else {
      throw VideoUploadError.exportFailed("Unable to add the H.264 writer input")
    }
    writer.add(writerInput)

    return AssetWriterStream(input: writerInput, output: readerOutput, label: "video")
  }

  private func makeAudioStream(
    track: AVAssetTrack,
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws -> AssetWriterStream {
    let audioDescription = try await Self.audioDescription(for: track)
    let readerOutput = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM]
    )
    readerOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(readerOutput) else {
      throw VideoUploadError.exportFailed("Unable to add the audio reader output")
    }
    reader.add(readerOutput)

    let writerInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVEncoderBitRateKey: Self.targetAudioBitRate,
        AVSampleRateKey: audioDescription.sampleRate,
        AVNumberOfChannelsKey: audioDescription.channelCount,
      ]
    )
    writerInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(writerInput) else {
      throw VideoUploadError.exportFailed("Unable to add the AAC writer input")
    }
    writer.add(writerInput)

    return AssetWriterStream(input: writerInput, output: readerOutput, label: "audio")
  }

  private static func outputGeometry(
    naturalSize: CGSize,
    preferredTransform: CGAffineTransform
  ) throws -> VideoOutputGeometry {
    let sourceWidth = abs(naturalSize.width)
    let sourceHeight = abs(naturalSize.height)
    guard
      sourceWidth.isFinite,
      sourceHeight.isFinite,
      sourceWidth >= 2,
      sourceHeight >= 2
    else {
      throw VideoUploadError.exportFailed("Invalid source video dimensions")
    }

    let renderedWidth =
      abs(preferredTransform.a * sourceWidth) + abs(preferredTransform.c * sourceHeight)
    let renderedHeight =
      abs(preferredTransform.b * sourceWidth) + abs(preferredTransform.d * sourceHeight)
    let renderedLongEdge = max(renderedWidth, renderedHeight)
    guard renderedLongEdge.isFinite, renderedLongEdge > 0 else {
      throw VideoUploadError.exportFailed("Invalid source video transform")
    }

    let scale = min(1, maximumRenderedEdge / renderedLongEdge)
    let width = evenDimension(sourceWidth * scale)
    let height = evenDimension(sourceHeight * scale)
    let transform = CGAffineTransform(
      a: preferredTransform.a,
      b: preferredTransform.b,
      c: preferredTransform.c,
      d: preferredTransform.d,
      tx: preferredTransform.tx * scale,
      ty: preferredTransform.ty * scale
    )
    return VideoOutputGeometry(width: width, height: height, transform: transform)
  }

  private static func evenDimension(_ value: CGFloat) -> Int {
    max(2, Int(value.rounded(.down)) / 2 * 2)
  }

  private static func outputVideoBitRate(sourceBitRate: Float) -> Int {
    guard sourceBitRate.isFinite, sourceBitRate > 0 else { return targetVideoBitRate }
    return min(targetVideoBitRate, max(1, Int(sourceBitRate.rounded(.down))))
  }

  private static func audioDescription(for track: AVAssetTrack) async throws
    -> AudioOutputDescription
  {
    let descriptions = try await track.load(.formatDescriptions)
    guard
      let formatDescription = descriptions.first,
      let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
    else {
      throw VideoUploadError.exportFailed("Unable to read the source audio format")
    }

    let sampleRate = basicDescription.pointee.mSampleRate
    let sourceChannelCount = Int(basicDescription.pointee.mChannelsPerFrame)
    guard sampleRate.isFinite, sampleRate > 0, sourceChannelCount > 0 else {
      throw VideoUploadError.exportFailed("Invalid source audio format")
    }
    return AudioOutputDescription(
      sampleRate: sampleRate,
      channelCount: min(sourceChannelCount, 2)
    )
  }
}

private struct VideoOutputGeometry {
  let width: Int
  let height: Int
  let transform: CGAffineTransform
}

private struct AudioOutputDescription {
  let sampleRate: Double
  let channelCount: Int
}
