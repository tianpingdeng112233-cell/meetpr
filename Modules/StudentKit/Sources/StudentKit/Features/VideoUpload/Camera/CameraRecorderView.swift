#if os(iOS)
  import SwiftUI
  import UIKit

  struct CameraRecorderView: View {
    private static let savePreferenceKey = "videoRecorder.saveToPhotoLibrary"

    let maxDurationSeconds: TimeInterval
    @Binding var isPresented: Bool
    let onPicked: (URL) -> Void
    let onFailure: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: RecorderSessionController
    @State private var saveToPhotoLibrary: Bool
    @State private var toastMessage: String?
    @State private var isUsingRecording = false
    @State private var isApplyingTrim = false
    @State private var recordingToTrim: VideoTrimSession?
    @State private var activeRecordingTrimSession: VideoTrimSession?
    @State private var trimSuggestionState: RecorderTrimSuggestionState
    @State private var didRequestShutdown = false

    init(
      maxDurationSeconds: TimeInterval,
      isPresented: Binding<Bool>,
      onPicked: @escaping (URL) -> Void,
      onFailure: @escaping () -> Void
    ) {
      self.maxDurationSeconds = maxDurationSeconds
      _isPresented = isPresented
      self.onPicked = onPicked
      self.onFailure = onFailure
      _controller = State(
        initialValue: RecorderSessionController(maximumDuration: maxDurationSeconds)
      )
      _saveToPhotoLibrary = State(
        initialValue: UserDefaults.standard.object(forKey: Self.savePreferenceKey) as? Bool ?? true
      )
      _trimSuggestionState = State(
        initialValue: RecorderTrimSuggestionState(
          isPermanentlyDisabled:
            RecorderTrimSuggestionPreference.isPermanentlyDisabled()
        )
      )
    }

    static var isAvailable: Bool {
      RecorderSessionWorker.isCameraAvailable
    }

    var body: some View {
      ZStack {
        Color.black.ignoresSafeArea()
        switch controller.phase {
        case .preparing:
          ProgressView("正在准备相机…")
            .tint(.white)
            .foregroundStyle(.white)
        case .ready, .starting, .recording, .stopping:
          RecorderCaptureView(
            session: controller.captureSession,
            phase: controller.phase,
            recordedDuration: controller.recordedDuration,
            maximumDuration: maxDurationSeconds,
            onClose: close,
            onRecordToggle: toggleRecording
          )
        case .review:
          if let url = controller.reviewURL {
            RecorderReviewView(
              url: url,
              duration: controller.recordedDuration,
              saveToPhotoLibrary: saveToggleBinding,
              isBusy: isUsingRecording || isApplyingTrim,
              showsTrimSuggestion: trimSuggestionState.shouldShow,
              onTrim: { prepareTrim(of: url) },
              onNeverSuggestTrim: disableTrimSuggestion,
              onUse: { Task { await useRecording(url) } },
              onClose: close
            )
          }
        case .permissionDenied:
          RecorderStatusView(
            systemImage: "lock.trianglebadge.exclamationmark",
            title: "需要相机和麦克风权限",
            message: "请在系统设置中允许 MeetPR 使用相机和麦克风后再试。",
            primaryAction: .init(title: "打开设置", systemImage: "gear", action: openSettings),
            secondaryAction: .init(title: "关闭", action: close)
          )
        case .unavailable:
          RecorderStatusView(
            systemImage: "video.slash",
            title: "相机不可用",
            message: "当前设备没有可用的后置相机。",
            secondaryAction: .init(title: "关闭", action: close)
          )
        case .failed(let message):
          RecorderStatusView(
            systemImage: "exclamationmark.triangle",
            title: "录制未完成",
            message: message,
            primaryAction: .init(
              title: "重试",
              systemImage: "arrow.clockwise",
              action: { Task { await controller.retry() } }
            ),
            secondaryAction: .init(
              title: "关闭",
              action: {
                onFailure()
                close()
              }
            )
          )
        }

        if let toastMessage {
          RecorderToastView(message: toastMessage)
            .transition(.opacity)
        }
      }
      .fullScreenCover(
        item: $recordingToTrim,
        onDismiss: finishRecordingTrimPresentation
      ) { session in
        VideoTrimmerView(session: session)
          .ignoresSafeArea()
      }
      .task {
        // Students frame the shot, walk to the bar, and never touch the
        // screen mid-set: the idle timer must not blank the display while
        // the recorder is up. (UIImagePickerController did this for us;
        // a custom AVCaptureSession does not.)
        UIApplication.shared.isIdleTimerDisabled = true
        if controller.phase == .preparing {
          await controller.prepare()
        }
      }
      .onDisappear {
        // A full-screen editor temporarily hides this view without ending the
        // recorder. External dismissal flips `isPresented` to false and takes
        // the shutdown path below, including both trim files and idle timer.
        guard activeRecordingTrimSession == nil || !isPresented else { return }
        shutdownRecorder()
      }
      .onChange(of: isPresented) { _, isPresented in
        if !isPresented { shutdownRecorder() }
      }
      .onChange(of: scenePhase) { _, newPhase in
        Task {
          switch newPhase {
          case .active:
            await controller.handleApplicationDidBecomeActive()
          case .background:
            await controller.handleApplicationDidEnterBackground()
          case .inactive:
            break
          @unknown default:
            break
          }
        }
      }
    }

  }

  extension CameraRecorderView {
    private var saveToggleBinding: Binding<Bool> {
      Binding(
        get: { saveToPhotoLibrary },
        set: { newValue in
          if !newValue {
            setSavePreference(false)
            return
          }
          Task {
            if await VideoLibrarySaver.requestAuthorization() {
              setSavePreference(true)
            } else {
              setSavePreference(false)
              showToast("未能获得相册权限")
            }
          }
        }
      )
    }

    private func toggleRecording() {
      Task {
        if controller.phase == .recording {
          await controller.stopRecording()
        } else {
          await controller.startRecording()
        }
      }
    }

    private func prepareTrim(of sourceURL: URL) {
      guard recordingToTrim == nil, !isUsingRecording, !isApplyingTrim else { return }
      guard UIVideoEditorController.canEditVideo(atPath: sourceURL.path) else {
        showToast("当前视频无法剪辑")
        return
      }
      do {
        let workingURL = try RecorderVideoTrimFiles.makeWorkingCopy(of: sourceURL)
        let session = VideoTrimSession(
          sourceURL: workingURL,
          maxDurationSeconds: maxDurationSeconds,
          onSave: applyTrim,
          onCancel: { recordingToTrim = nil },
          onFailure: {
            recordingToTrim = nil
            showToast("剪辑失败，请重试")
          }
        )
        activeRecordingTrimSession = session
        recordingToTrim = session
      } catch {
        showToast("暂时无法开始剪辑")
      }
    }

    private func applyTrim(_ editedURL: URL) {
      isApplyingTrim = true
      recordingToTrim = nil
      trimSuggestionState.completeTrim()
      Task {
        await controller.replaceReviewFile(with: editedURL)
        isApplyingTrim = false
      }
    }

    private func useRecording(_ url: URL) async {
      guard !isUsingRecording else { return }
      isUsingRecording = true

      if saveToPhotoLibrary {
        let saved = await VideoLibrarySaver.save(url)
        if !saved {
          onPicked(url)
          await controller.relinquishReviewFile()
          showToast("保存到相册失败，视频仍会继续上传")
          try? await Task.sleep(for: .seconds(1.2))
          isPresented = false
          return
        }
      }

      onPicked(url)
      await controller.relinquishReviewFile()
      isPresented = false
    }

    private func close() {
      isPresented = false
      shutdownRecorder()
    }

    private func openSettings() {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(url)
    }

    private func setSavePreference(_ enabled: Bool) {
      saveToPhotoLibrary = enabled
      UserDefaults.standard.set(enabled, forKey: Self.savePreferenceKey)
    }

    private func disableTrimSuggestion() {
      trimSuggestionState.disablePermanently()
      RecorderTrimSuggestionPreference.disablePermanently()
    }

    private func finishRecordingTrimPresentation() {
      activeRecordingTrimSession?.cancelled()
      activeRecordingTrimSession = nil
      recordingToTrim = nil
      if !isPresented { shutdownRecorder() }
    }

    private func shutdownRecorder() {
      guard !didRequestShutdown else { return }
      didRequestShutdown = true
      activeRecordingTrimSession?.cancelled()
      activeRecordingTrimSession = nil
      recordingToTrim = nil
      UIApplication.shared.isIdleTimerDisabled = false
      Task { await controller.close() }
    }

    private func showToast(_ message: String) {
      withAnimation { toastMessage = message }
      Task {
        try? await Task.sleep(for: .seconds(2))
        withAnimation {
          if toastMessage == message { toastMessage = nil }
        }
      }
    }
  }

#endif
