#if os(iOS)
  import AVFoundation
  import CoreMedia
  import Foundation

  /// Serializes all sample and writer state on `queue`; the unchecked crossing
  /// is limited to AVFoundation's delegate callbacks and queue handoffs.
  final class RecorderCapturePipeline: NSObject, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.meetpr.camera-recorder.samples")

    private var writer: RecorderAssetWriter?
    private var finishingWriter: RecorderAssetWriter?
    private var maximumDuration: TimeInterval = 0
    private var lastReportedDuration: TimeInterval = -1
    private var didRequestAutomaticStop = false
    private var videoOutputID: ObjectIdentifier?
    private var onDuration: (@Sendable (TimeInterval) -> Void)?
    private var onAutomaticStop: (@Sendable () -> Void)?
    private var onFailure: (@Sendable (String) -> Void)?

    func identify(videoOutput: AVCaptureVideoDataOutput) {
      videoOutputID = ObjectIdentifier(videoOutput)
    }

    func startRecording(
      to outputURL: URL,
      maximumDuration: TimeInterval,
      onDuration: @escaping @Sendable (TimeInterval) -> Void,
      onAutomaticStop: @escaping @Sendable () -> Void,
      onFailure: @escaping @Sendable (String) -> Void
    ) async throws {
      try await withCheckedThrowingContinuation { continuation in
        queue.async { [self] in
          do {
            writer?.cancel()
            finishingWriter?.cancel()
            finishingWriter = nil
            writer = try RecorderAssetWriter(outputURL: outputURL)
            self.maximumDuration = maximumDuration
            lastReportedDuration = -1
            didRequestAutomaticStop = false
            self.onDuration = onDuration
            self.onAutomaticStop = onAutomaticStop
            self.onFailure = onFailure
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }

    func finishRecording() async throws -> URL {
      try await withCheckedThrowingContinuation { continuation in
        queue.async { [self] in
          guard let writer else {
            continuation.resume(throwing: CameraRecorderError.noVideoSamples)
            return
          }
          self.writer = nil
          finishingWriter = writer
          onDuration = nil
          onAutomaticStop = nil
          onFailure = nil
          Task { [self] in
            let result: Result<URL, any Error>
            do {
              result = .success(try await writer.finish())
            } catch {
              result = .failure(error)
            }
            queue.async { [self] in
              if finishingWriter === writer {
                finishingWriter = nil
              }
              continuation.resume(with: result)
            }
          }
        }
      }
    }

    func cancelRecording() async {
      await withCheckedContinuation { continuation in
        queue.async { [self] in
          writer?.cancel()
          finishingWriter?.cancel()
          writer = nil
          finishingWriter = nil
          onDuration = nil
          onAutomaticStop = nil
          onFailure = nil
          continuation.resume()
        }
      }
    }
  }

  extension RecorderCapturePipeline: AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate
  {
    func captureOutput(
      _ output: AVCaptureOutput,
      didOutput sampleBuffer: CMSampleBuffer,
      from connection: AVCaptureConnection
    ) {
      guard let writer else { return }
      guard !didRequestAutomaticStop else { return }
      do {
        if ObjectIdentifier(output) == videoOutputID {
          guard let duration = try writer.appendVideo(sampleBuffer) else { return }
          if duration - lastReportedDuration >= 0.05 {
            lastReportedDuration = duration
            onDuration?(min(duration, maximumDuration))
          }
          if duration >= maximumDuration, !didRequestAutomaticStop {
            didRequestAutomaticStop = true
            onAutomaticStop?()
          }
        } else {
          try writer.appendAudio(sampleBuffer)
        }
      } catch {
        let failureHandler = onFailure
        writer.cancel()
        self.writer = nil
        onDuration = nil
        onAutomaticStop = nil
        onFailure = nil
        failureHandler?(error.localizedDescription)
      }
    }
  }
#endif
