#if os(iOS)
  import AVFoundation
  import CoreMedia
  import Foundation

  /// Crosses from the serial capture queue only when ownership is transferred
  /// to the finishing task; the pipeline removes its reference before that hop.
  final class RecorderAssetWriter: @unchecked Sendable {
    private let outputURL: URL
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private var sessionStartTime: CMTime?

    init(outputURL: URL) throws {
      self.outputURL = outputURL
      try? FileManager.default.removeItem(at: outputURL)

      let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
      writer.shouldOptimizeForNetworkUse = true

      let videoInput = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: RecorderWriterSettings.video()
      )
      videoInput.expectsMediaDataInRealTime = true
      videoInput.transform = RecorderWriterSettings.videoTransform

      let audioInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: RecorderWriterSettings.audio()
      )
      audioInput.expectsMediaDataInRealTime = true

      guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
        throw CameraRecorderError.assetWriterSetupFailed
      }
      writer.add(videoInput)
      writer.add(audioInput)

      self.writer = writer
      self.videoInput = videoInput
      self.audioInput = audioInput
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) throws -> TimeInterval? {
      guard CMSampleBufferDataIsReady(sampleBuffer) else { return nil }
      let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      if sessionStartTime == nil {
        guard writer.startWriting() else {
          throw CameraRecorderError.assetWriterFailed(writer.error)
        }
        writer.startSession(atSourceTime: presentationTime)
        sessionStartTime = presentationTime
      }
      try append(sampleBuffer, to: videoInput)
      guard let sessionStartTime else { return nil }
      return max(0, CMTimeGetSeconds(presentationTime - sessionStartTime))
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) throws {
      guard sessionStartTime != nil, CMSampleBufferDataIsReady(sampleBuffer) else { return }
      try append(sampleBuffer, to: audioInput)
    }

    func finish() async throws -> URL {
      guard sessionStartTime != nil else {
        cancel()
        throw CameraRecorderError.noVideoSamples
      }
      videoInput.markAsFinished()
      audioInput.markAsFinished()
      await writer.finishWriting()
      guard writer.status == .completed else {
        try? FileManager.default.removeItem(at: outputURL)
        throw CameraRecorderError.assetWriterFailed(writer.error)
      }
      return outputURL
    }

    func cancel() {
      if writer.status == .writing || writer.status == .unknown {
        writer.cancelWriting()
      }
      try? FileManager.default.removeItem(at: outputURL)
    }

    private func append(
      _ sampleBuffer: CMSampleBuffer,
      to input: AVAssetWriterInput
    ) throws {
      guard writer.status == .writing else {
        throw CameraRecorderError.assetWriterFailed(writer.error)
      }
      guard input.isReadyForMoreMediaData else { return }
      guard input.append(sampleBuffer) else {
        throw CameraRecorderError.assetWriterFailed(writer.error)
      }
    }
  }

  enum CameraRecorderError: LocalizedError {
    case assetWriterSetupFailed
    case assetWriterFailed((any Error)?)
    case cameraConfigurationFailed
    case cameraUnavailable
    case noVideoSamples
    case rotationUnavailable

    var errorDescription: String? {
      switch self {
      case .assetWriterSetupFailed:
        StudentStrings.localized(.recorderAssetWriter001)
      case .assetWriterFailed(let error):
        error?.localizedDescription ?? StudentStrings.localized(.recorderAssetWriter002)
      case .cameraConfigurationFailed:
        StudentStrings.localized(.recorderAssetWriter003)
      case .cameraUnavailable:
        StudentStrings.localized(.recorderAssetWriter004)
      case .noVideoSamples:
        StudentStrings.localized(.recorderAssetWriter005)
      case .rotationUnavailable:
        StudentStrings.localized(.recorderAssetWriter006)
      }
    }
  }
#endif
