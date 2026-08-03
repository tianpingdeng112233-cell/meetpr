import AVFoundation
import CoreMedia

extension AVFoundationVideoExporter {
  static func exportDecision(
    videoTrack: AVAssetTrack,
    audioTrack: AVAssetTrack?
  ) async throws -> VideoExportDecision {
    let naturalSize = try await videoTrack.load(.naturalSize)
    let transform = try await videoTrack.load(.preferredTransform)
    let videoProperties = VideoTrackExportProperties(
      codecFourCCs: try await codecFourCCs(for: videoTrack),
      naturalSize: VideoDimensions(
        width: Double(naturalSize.width),
        height: Double(naturalSize.height)
      ),
      preferredTransform: VideoTransform(
        horizontalScale: Double(transform.a),
        verticalShear: Double(transform.b),
        horizontalShear: Double(transform.c),
        verticalScale: Double(transform.d)
      ),
      estimatedDataRate: Double(try await videoTrack.load(.estimatedDataRate))
    )
    let audioProperties: AudioTrackExportProperties?
    if let audioTrack {
      audioProperties = AudioTrackExportProperties(
        codecFourCCs: try await codecFourCCs(for: audioTrack),
        estimatedDataRate: Double(try await audioTrack.load(.estimatedDataRate))
      )
    } else {
      audioProperties = nil
    }
    return VideoPassthroughEligibility.decision(video: videoProperties, audio: audioProperties)
  }

  func makeStreams(
    videoTrack: AVAssetTrack,
    audioTrack: AVAssetTrack?,
    decision: VideoExportDecision,
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws -> [AssetWriterStream] {
    let videoStream: AssetWriterStream
    switch decision {
    case .passthrough:
      videoStream = try await makePassthroughStream(
        track: videoTrack,
        mediaType: .video,
        reader: reader,
        writer: writer
      )
    case .transcode:
      videoStream = try await makeVideoStream(track: videoTrack, reader: reader, writer: writer)
    }
    guard let audioTrack else { return [videoStream] }

    let audioStream: AssetWriterStream
    switch decision {
    case .passthrough:
      audioStream = try await makePassthroughStream(
        track: audioTrack,
        mediaType: .audio,
        reader: reader,
        writer: writer
      )
    case .transcode:
      audioStream = try await makeAudioStream(track: audioTrack, reader: reader, writer: writer)
    }
    return [videoStream, audioStream]
  }

  private static func codecFourCCs(for track: AVAssetTrack) async throws -> [UInt32] {
    let descriptions = try await track.load(.formatDescriptions)
    return descriptions.map(CMFormatDescriptionGetMediaSubType)
  }

  private func makePassthroughStream(
    track: AVAssetTrack,
    mediaType: AVMediaType,
    reader: AVAssetReader,
    writer: AVAssetWriter
  ) async throws -> AssetWriterStream {
    let descriptions = try await track.load(.formatDescriptions)
    let sourceFormatHint = descriptions.first
    let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    readerOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(readerOutput) else {
      throw VideoUploadError.exportFailed("Unable to add the passthrough reader output")
    }
    reader.add(readerOutput)

    let writerInput = AVAssetWriterInput(
      mediaType: mediaType,
      outputSettings: nil,
      sourceFormatHint: sourceFormatHint
    )
    writerInput.expectsMediaDataInRealTime = false
    if mediaType == .video {
      writerInput.transform = try await track.load(.preferredTransform)
    }
    guard writer.canAdd(writerInput) else {
      throw VideoUploadError.exportFailed("Unable to add the passthrough writer input")
    }
    writer.add(writerInput)

    return AssetWriterStream(input: writerInput, output: readerOutput, label: mediaType.rawValue)
  }
}
