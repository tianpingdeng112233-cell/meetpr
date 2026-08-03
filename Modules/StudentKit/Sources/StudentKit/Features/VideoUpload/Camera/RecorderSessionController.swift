#if os(iOS)
  import AVFoundation
  import Foundation
  import Observation

  enum CameraRecorderPhase: Equatable {
    case preparing
    case ready
    case starting
    case recording
    case stopping
    case review
    case permissionDenied
    case unavailable
    case failed(String)
  }

  @MainActor
  @Observable
  final class RecorderSessionController {
    private(set) var phase: CameraRecorderPhase = .preparing
    private(set) var recordedDuration: TimeInterval = 0
    private(set) var reviewURL: URL?

    let maximumDuration: TimeInterval
    let captureSession: AVCaptureSession

    private let worker: RecorderSessionWorker
    private var machine = RecorderStateMachine()
    private var notificationTokens: [NSObjectProtocol] = []
    private var ownsReviewFile = true

    init(maximumDuration: TimeInterval) {
      self.maximumDuration = maximumDuration
      let worker = RecorderSessionWorker()
      self.worker = worker
      captureSession = worker.session
      observeInterruptions()
    }

    func prepare() async {
      guard machine.beginPreparation() else { return }
      phase = .preparing
      guard RecorderSessionWorker.isCameraAvailable else {
        machine.markUnavailable()
        phase = .unavailable
        return
      }
      guard await requestCapturePermissions() else {
        machine.denyPermission()
        phase = .permissionDenied
        return
      }
      guard machine.state == .preparing else { return }

      do {
        try await worker.configureAndStart()
        guard machine.completePreparation() else {
          await worker.stopSession()
          return
        }
        phase = .ready
      } catch {
        guard machine.state == .preparing else { return }
        machine.failPreparation()
        phase = .failed(error.localizedDescription)
      }
    }

    func startRecording() async {
      guard let generation = machine.beginRecording() else { return }
      phase = .starting
      recordedDuration = 0
      let outputURL = FileManager.default.temporaryDirectory
        .appending(path: "meetpr-camera-\(UUID().uuidString).mp4")
      do {
        try await worker.startRecording(
          to: outputURL,
          maximumDuration: maximumDuration,
          onDuration: { [weak self] duration in
            Task { @MainActor in
              guard let self else { return }
              guard self.machine.state == .recording(generation: generation) else { return }
              self.recordedDuration = duration
            }
          },
          onAutomaticStop: { [weak self] in
            Task { @MainActor in
              await self?.stopRecording(expectedGeneration: generation)
            }
          },
          onFailure: { [weak self] message in
            Task { @MainActor in
              await self?.handleRecordingFailure(
                generation: generation,
                outputURL: outputURL,
                message: message
              )
            }
          }
        )
        guard machine.completeRecordingStart(generation: generation) else {
          await worker.cancelRecording()
          try? FileManager.default.removeItem(at: outputURL)
          return
        }
        phase = .recording
      } catch {
        try? FileManager.default.removeItem(at: outputURL)
        guard machine.failActiveOperation(generation: generation) else { return }
        phase = .failed(error.localizedDescription)
      }
    }

    func stopRecording() async {
      await stopRecording(expectedGeneration: nil)
    }

    func retake() async {
      guard machine.beginRetake() else { return }
      phase = .preparing
      removeOwnedReviewFile()
      reviewURL = nil
      recordedDuration = 0
      do {
        try await worker.configureAndStart()
        guard machine.completePreparation() else {
          await worker.stopSession()
          return
        }
        phase = .ready
      } catch {
        guard machine.state == .preparing else { return }
        machine.failPreparation()
        phase = .failed(error.localizedDescription)
      }
    }

    func retry() async {
      await prepare()
    }

    func relinquishReviewFile() async {
      machine.close()
      ownsReviewFile = false
      reviewURL = nil
      await worker.stopSession()
    }

    func close() async {
      machine.close()
      await worker.cancelRecording()
      removeOwnedReviewFile()
      reviewURL = nil
      await worker.stopSession()
      removeInterruptionObservers()
    }

    func handleApplicationDidEnterBackground() async {
      if machine.activeGeneration != nil {
        await interruptRecording(message: "录制已中断，请重试")
      } else if machine.state != .review {
        await worker.stopSession()
      }
    }

    func handleApplicationDidBecomeActive() async {
      guard machine.state != .closed else { return }
      if machine.state == .permissionDenied {
        guard capturePermissionsGranted else { return }
        await prepare()
        return
      }
      guard machine.state == .ready else { return }
      guard capturePermissionsGranted else {
        machine.denyPermission()
        phase = .permissionDenied
        await worker.stopSession()
        return
      }
      do {
        try await worker.configureAndStart()
      } catch {
        machine.beginPreparation()
        machine.failPreparation()
        phase = .failed(error.localizedDescription)
      }
    }

    private func stopRecording(expectedGeneration: Int?) async {
      guard let generation = machine.beginStopping(expectedGeneration: expectedGeneration) else {
        return
      }
      phase = .stopping
      do {
        let url = try await worker.finishRecording()
        await worker.stopSession()
        guard machine.completeStop(generation: generation) else {
          try? FileManager.default.removeItem(at: url)
          return
        }
        recordedDuration = min(recordedDuration, maximumDuration)
        reviewURL = url
        ownsReviewFile = true
        phase = .review
      } catch {
        await worker.cancelRecording()
        guard machine.failActiveOperation(generation: generation) else { return }
        phase = .failed(error.localizedDescription)
      }
    }

    private var capturePermissionsGranted: Bool {
      AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func requestCapturePermissions() async -> Bool {
      let cameraGranted = await requestPermission(for: .video)
      guard cameraGranted else { return false }
      return await requestPermission(for: .audio)
    }

    private func requestPermission(for mediaType: AVMediaType) async -> Bool {
      switch AVCaptureDevice.authorizationStatus(for: mediaType) {
      case .authorized:
        true
      case .notDetermined:
        await AVCaptureDevice.requestAccess(for: mediaType)
      default:
        false
      }
    }

    private func observeInterruptions() {
      let center = NotificationCenter.default
      notificationTokens.append(
        center.addObserver(
          forName: .AVCaptureSessionWasInterrupted,
          object: captureSession,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in
            guard let self, self.machine.activeGeneration != nil else { return }
            await self.interruptRecording(message: "录制已中断，请重试")
          }
        }
      )
      notificationTokens.append(
        center.addObserver(
          forName: .AVCaptureSessionRuntimeError,
          object: captureSession,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in
            guard let self, self.machine.activeGeneration != nil else { return }
            await self.interruptRecording(message: "相机发生错误，请重试")
          }
        }
      )
    }

    private func removeInterruptionObservers() {
      for token in notificationTokens {
        NotificationCenter.default.removeObserver(token)
      }
      notificationTokens.removeAll()
    }

    private func interruptRecording(message: String) async {
      guard machine.interruptActiveOperation() else { return }
      phase = .failed(message)
      await worker.cancelRecording()
      await worker.stopSession()
      recordedDuration = 0
      reviewURL = nil
    }

    private func removeOwnedReviewFile() {
      guard ownsReviewFile, let reviewURL else { return }
      try? FileManager.default.removeItem(at: reviewURL)
      ownsReviewFile = false
    }
  }

  extension RecorderSessionController {
    fileprivate func handleRecordingFailure(
      generation: Int,
      outputURL: URL,
      message: String
    ) async {
      guard machine.failActiveOperation(generation: generation) else { return }
      phase = .failed(message)
      recordedDuration = 0
      reviewURL = nil
      await worker.cancelRecording()
      try? FileManager.default.removeItem(at: outputURL)
    }
  }
#endif
