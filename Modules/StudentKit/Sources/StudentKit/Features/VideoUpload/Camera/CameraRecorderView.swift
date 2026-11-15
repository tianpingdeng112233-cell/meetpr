#if os(iOS)
  import PhotosUI
  import SwiftUI
  import UIKit

  struct CameraRecorderView: View {
    private static let savePreferenceKey = "videoRecorder.saveToPhotoLibrary"

    let maxDurationSeconds: TimeInterval
    @Binding var isPresented: Bool
    let onPicked: (URL) -> Void
    let onFailure: () -> Void
    let allDayFlow: Bool
    @State private var pickedAlbumVideo: PhotosPickerItem?
    @State private var albumImportTask: Task<Void, Never>?
    @State private var isImportingAlbumVideo = false
    @State private var showingAlbumImportFailure = false
    @State private var albumTrimFailed = false

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
      onFailure: @escaping () -> Void,
      allDayFlow: Bool = false
    ) {
      self.maxDurationSeconds = maxDurationSeconds
      _isPresented = isPresented
      self.onPicked = onPicked
      self.onFailure = onFailure
      self.allDayFlow = allDayFlow
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
        Group {
          switch controller.phase {
          case .preparing:
            ProgressView(StudentStrings.localized(.cameraRecorderView001))
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
              title: StudentStrings.localized(.cameraRecorderView002),
              message: StudentStrings.localized(.cameraRecorderView003),
              primaryAction: .init(
                title: StudentStrings.localized(.cameraRecorderView004), systemImage: "gear",
                action: openSettings),
              secondaryAction: .init(
                title: StudentStrings.localized(.cameraRecorderView005), action: close)
            )
          case .unavailable:
            RecorderStatusView(
              systemImage: "video.slash",
              title: StudentStrings.localized(.cameraRecorderView006),
              message: StudentStrings.localized(.cameraRecorderView007),
              secondaryAction: .init(
                title: StudentStrings.localized(.cameraRecorderView005), action: close)
            )
          case .failed(let message):
            RecorderStatusView(
              systemImage: "exclamationmark.triangle",
              title: StudentStrings.localized(.cameraRecorderView008),
              message: message,
              primaryAction: .init(
                title: StudentStrings.localized(.cameraRecorderView009),
                systemImage: "arrow.clockwise",
                action: { Task { await controller.retry() } }
              ),
              secondaryAction: .init(
                title: StudentStrings.localized(.cameraRecorderView005),
                action: {
                  onFailure()
                  close()
                }
              )
            )
          }
        }
        .disabled(isImportingAlbumVideo)
        .accessibilityHidden(isImportingAlbumVideo)

        if let toastMessage {
          RecorderToastView(message: toastMessage)
        }
        if isImportingAlbumVideo {
          RecorderAlbumImportView(onClose: close)
        }
      }
      .overlay(alignment: .bottomLeading) {
        if allDayFlow, controller.phase != .recording, controller.phase != .review {
          PhotosPicker(
            selection: $pickedAlbumVideo, matching: .videos, preferredItemEncoding: .current
          ) {
            Label(StudentStrings.localized(.allDayAlbum), systemImage: "photo")
              .padding().foregroundStyle(.white)
          }
          .disabled(isImportingAlbumVideo)
          .padding(.bottom, 32)
        }
      }
      .onChange(of: pickedAlbumVideo) { _, item in
        guard let item, !isImportingAlbumVideo else { return }
        pickedAlbumVideo = nil
        isImportingAlbumVideo = true
        albumImportTask = Task { await importAlbumVideo(item) }
      }
      .alert(
        StudentStrings.localized(.videoAttachmentViewModel001),
        isPresented: $showingAlbumImportFailure
      ) {
        Button(StudentStrings.localized(.cameraRecorderView005), role: .cancel) {}
      }
      .onChange(of: controller.phase) { _, phase in
        if allDayFlow, phase == .review, let url = controller.reviewURL,
          activeRecordingTrimSession == nil
        {
          prepareTrim(of: url)
        }
      }
      .fullScreenCover(
        item: $recordingToTrim,
        onDismiss: finishRecordingTrimPresentation
      ) { session in
        VideoTrimView(session: session, uploadsOnSave: allDayFlow)
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
        // Editor presentation hides the recorder; external dismissal shuts it down.
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
              showToast(StudentStrings.localized(.cameraRecorderView010))
            }
          }
        }
      )
    }

    private func toggleRecording() {
      guard !isImportingAlbumVideo else { return }
      Task {
        if controller.phase == .recording {
          await controller.stopRecording()
        } else {
          await controller.startRecording()
        }
      }
    }

    private func importAlbumVideo(_ item: PhotosPickerItem) async {
      defer {
        isImportingAlbumVideo = false
        albumImportTask = nil
      }
      do {
        let movie = try await item.loadTransferable(type: PickedVideo.self)
        // Discard a provider's late copy after the recorder closes.
        guard isPresented, !Task.isCancelled else {
          if let movie { try? FileManager.default.removeItem(at: movie.url) }
          return
        }
        guard let movie else {
          VideoProcessingDiagnostics().report(.picker, code: .noTransferable)
          reportAlbumImportFailure()
          return
        }
        let session = VideoTrimSession(
          sourceURL: movie.url, maxDurationSeconds: maxDurationSeconds,
          onSave: { url in
            activeRecordingTrimSession = nil
            recordingToTrim = nil
            onPicked(url)
            isPresented = false
          },
          onCancel: { recordingToTrim = nil },
          onFailure: {
            albumTrimFailed = true
            recordingToTrim = nil
          })
        activeRecordingTrimSession = session
        recordingToTrim = session
      } catch {
        guard isPresented, !Task.isCancelled else { return }
        VideoProcessingDiagnostics().report(.picker, error: error)
        reportAlbumImportFailure()
      }
    }

    private func reportAlbumImportFailure() {
      showingAlbumImportFailure = true
      onFailure()
    }

    private func prepareTrim(of sourceURL: URL) {
      guard recordingToTrim == nil, !isUsingRecording, !isApplyingTrim else { return }
      do {
        let workingURL = try RecorderVideoTrimFiles.makeWorkingCopy(of: sourceURL)
        let session = VideoTrimSession(
          sourceURL: workingURL,
          maxDurationSeconds: maxDurationSeconds,
          onSave: applyTrim,
          onCancel: { recordingToTrim = nil },
          onFailure: {
            recordingToTrim = nil
            showToast(StudentStrings.localized(.cameraRecorderView011))
          }
        )
        activeRecordingTrimSession = session
        recordingToTrim = session
      } catch {
        showToast(StudentStrings.localized(.cameraRecorderView012))
      }
    }

    private func applyTrim(_ editedURL: URL) {
      isApplyingTrim = true
      recordingToTrim = nil
      trimSuggestionState.completeTrim()
      Task {
        await controller.replaceReviewFile(with: editedURL)
        isApplyingTrim = false
        if allDayFlow { await useRecording(editedURL) }
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
          showToast(StudentStrings.localized(.cameraRecorderView013))
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
      let shouldReportFailure = albumTrimFailed
      albumTrimFailed = false
      if !isPresented {
        shutdownRecorder()
      } else if shouldReportFailure {
        // Present only after the failed editor has fully dismissed.
        reportAlbumImportFailure()
      }
    }

    private func shutdownRecorder() {
      guard !didRequestShutdown else { return }
      didRequestShutdown = true
      albumImportTask?.cancel()
      albumImportTask = nil
      activeRecordingTrimSession?.cancelled()
      activeRecordingTrimSession = nil
      recordingToTrim = nil
      UIApplication.shared.isIdleTimerDisabled = false
      Task { await controller.close() }
    }

    private func showToast(_ message: String) {
      toastMessage = message
      Task {
        try? await Task.sleep(for: .seconds(2))
        if toastMessage == message { toastMessage = nil }
      }
    }
  }

#endif
