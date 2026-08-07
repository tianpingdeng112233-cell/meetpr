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
              saveToPhotoLibrary: saveToggleBinding,
              isUsingRecording: isUsingRecording,
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
      .task {
        await controller.prepare()
      }
      .onDisappear {
        Task { await controller.close() }
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
      Task {
        await controller.close()
        isPresented = false
      }
    }

    private func openSettings() {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(url)
    }

    private func setSavePreference(_ enabled: Bool) {
      saveToPhotoLibrary = enabled
      UserDefaults.standard.set(enabled, forKey: Self.savePreferenceKey)
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
