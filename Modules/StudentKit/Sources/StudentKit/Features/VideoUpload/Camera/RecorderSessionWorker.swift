#if os(iOS)
  import AVFoundation
  import CoreMedia
  import Foundation

  /// Owns capture-session mutation on `sessionQueue` and exposes the session
  /// itself read-only for the preview layer.
  final class RecorderSessionWorker: @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.meetpr.camera-recorder.session")
    private let capturePipeline = RecorderCapturePipeline()
    private var isConfigured = false

    static var isCameraAvailable: Bool {
      AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func configureAndStart() async throws {
      try await performOnSessionQueue {
        if !self.isConfigured {
          try self.configure()
          self.isConfigured = true
        }
        if !self.session.isRunning {
          self.session.startRunning()
        }
      }
    }

    func stopSession() async {
      await performOnSessionQueue {
        if self.session.isRunning {
          self.session.stopRunning()
        }
      }
    }

    func startRecording(
      to outputURL: URL,
      maximumDuration: TimeInterval,
      onDuration: @escaping @Sendable (TimeInterval) -> Void,
      onAutomaticStop: @escaping @Sendable () -> Void,
      onFailure: @escaping @Sendable (String) -> Void
    ) async throws {
      try await capturePipeline.startRecording(
        to: outputURL,
        maximumDuration: maximumDuration,
        onDuration: onDuration,
        onAutomaticStop: onAutomaticStop,
        onFailure: onFailure
      )
    }

    func finishRecording() async throws -> URL {
      try await capturePipeline.finishRecording()
    }

    func cancelRecording() async {
      await capturePipeline.cancelRecording()
    }

    private func configure() throws {
      guard
        let camera = AVCaptureDevice.default(
          .builtInWideAngleCamera,
          for: .video,
          position: .back
        )
      else {
        throw CameraRecorderError.cameraUnavailable
      }

      session.beginConfiguration()
      defer { session.commitConfiguration() }
      guard session.canSetSessionPreset(.hd1280x720) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      session.sessionPreset = .hd1280x720

      try configureFrameRate(for: camera)
      try addCaptureInputs(camera: camera)
      let videoOutput = try addCaptureOutputs()

      guard
        let videoConnection = videoOutput.connection(with: .video),
        videoConnection.isVideoRotationAngleSupported(90)
      else {
        throw CameraRecorderError.rotationUnavailable
      }
      videoConnection.videoRotationAngle = 90
    }

    private func addCaptureInputs(camera: AVCaptureDevice) throws {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      guard session.canAddInput(cameraInput) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      session.addInput(cameraInput)

      guard let microphone = AVCaptureDevice.default(for: .audio) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      let microphoneInput = try AVCaptureDeviceInput(device: microphone)
      guard session.canAddInput(microphoneInput) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      session.addInput(microphoneInput)
    }

    private func addCaptureOutputs() throws -> AVCaptureVideoDataOutput {
      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.alwaysDiscardsLateVideoFrames = false
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
      ]
      guard session.canAddOutput(videoOutput) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      session.addOutput(videoOutput)
      capturePipeline.identify(videoOutput: videoOutput)
      videoOutput.setSampleBufferDelegate(capturePipeline, queue: capturePipeline.queue)

      let audioOutput = AVCaptureAudioDataOutput()
      guard session.canAddOutput(audioOutput) else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      session.addOutput(audioOutput)
      audioOutput.setSampleBufferDelegate(capturePipeline, queue: capturePipeline.queue)
      return videoOutput
    }

    private func configureFrameRate(for camera: AVCaptureDevice) throws {
      let preferredRate: Double = 60
      let fallbackRate: Double = 30
      let preferredFormat = format(for: camera, supporting: preferredRate)
      let selectedFormat = preferredFormat ?? format(for: camera, supporting: fallbackRate)
      guard let selectedFormat else {
        throw CameraRecorderError.cameraConfigurationFailed
      }
      let selectedRate = preferredFormat == nil ? fallbackRate : preferredRate

      try camera.lockForConfiguration()
      defer { camera.unlockForConfiguration() }
      camera.activeFormat = selectedFormat
      let frameDuration = CMTime(value: 1, timescale: CMTimeScale(selectedRate))
      camera.activeVideoMinFrameDuration = frameDuration
      camera.activeVideoMaxFrameDuration = frameDuration
    }

    private func format(
      for camera: AVCaptureDevice,
      supporting frameRate: Double
    ) -> AVCaptureDevice.Format? {
      camera.formats.first { format in
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard dimensions.width == 1_280, dimensions.height == 720 else { return false }
        return format.videoSupportedFrameRateRanges.contains { range in
          range.minFrameRate <= frameRate && range.maxFrameRate >= frameRate
        }
      }
    }

    private func performOnSessionQueue(
      _ operation: @escaping @Sendable () throws -> Void
    ) async throws {
      try await withCheckedThrowingContinuation { continuation in
        sessionQueue.async {
          do {
            try operation()
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }

    private func performOnSessionQueue(
      _ operation: @escaping @Sendable () -> Void
    ) async {
      await withCheckedContinuation { continuation in
        sessionQueue.async {
          operation()
          continuation.resume()
        }
      }
    }
  }
#endif
