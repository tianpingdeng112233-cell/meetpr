import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "附视频" block inside SetEntrySheet (spec 027): pick from the photo
/// library or record with the camera. Successful/background work stays
/// visually neutral; only a terminal failure surfaces upload semantics.
@available(iOS 17.0, macOS 14.0, *)
struct VideoAttachmentSection: View {
  let studentID: UUID
  let trainingDate: Date
  let videoViewModel: VideoAttachmentViewModel
  /// Set-log id when the row was already logged; nil until first commit.
  let initialSetLogID: UUID?
  /// Lazily creates the set log (preserving completion state) so a video can
  /// attach to a not-yet-completed set.
  let resolveSetLogID: @MainActor () async -> UUID?
  /// Runs before presenting the camera/library picker so the host can flush
  /// unsaved entry state that must survive any presentation churn.
  let onWillPick: (() -> Void)?

  @State private var resolvedSetLogID: UUID?
  @State private var showingConsent = false
  @State private var showingPhotosPicker = false
  @State private var showingCamera = false
  @State private var pickedItem: PhotosPickerItem?
  @State private var libraryVideoToTrim: PickedVideo?
  @State private var pendingSource: PendingSource?
  /// True from the moment a video is chosen until the upload manager owns a
  /// row for it. Covers the otherwise feedback-less window where the picked
  /// file is copied out of the picker sandbox (or saved to the library) before
  /// `enqueue` broadcasts its first `.pending` event.
  @State private var isPreparing = false

  private enum PendingSource {
    case camera
    case library
  }

  init(
    studentID: UUID,
    trainingDate: Date,
    videoViewModel: VideoAttachmentViewModel,
    initialSetLogID: UUID?,
    resolveSetLogID: @escaping @MainActor () async -> UUID?,
    onWillPick: (() -> Void)? = nil
  ) {
    self.studentID = studentID
    self.trainingDate = trainingDate
    self.videoViewModel = videoViewModel
    self.initialSetLogID = initialSetLogID
    self.resolveSetLogID = resolveSetLogID
    self.onWillPick = onWillPick
    _resolvedSetLogID = State(initialValue: initialSetLogID)
  }

  private var rowState: VideoAttachmentViewModel.RowState? {
    resolvedSetLogID.flatMap { videoViewModel.rowStates[$0] }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack(spacing: MeetPRSpacing.space3) {
        Text("视频")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .medium))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        VideoAttachmentV3Controls(
          state: presentationState,
          onCamera: { requestPick(.camera) },
          onLibrary: { requestPick(.library) },
          onCancel: { removeAttachment() },
          onRetry: { retryAttachment() },
          onDelete: { removeAttachment() }
        )
      }
      if let message = videoViewModel.lastErrorMessage {
        Text(message)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.danger)
      }
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point11)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .alert(VideoPrivacyCopy.consentTitle, isPresented: $showingConsent) {
      Button(VideoPrivacyCopy.consentAgree) {
        videoViewModel.recordConsent()
        if let pendingSource {
          present(pendingSource)
        }
        pendingSource = nil
      }
      Button(VideoPrivacyCopy.consentDecline, role: .cancel) {
        pendingSource = nil
      }
    } message: {
      Text(VideoPrivacyCopy.consentBody)
    }
    .photosPicker(isPresented: $showingPhotosPicker, selection: $pickedItem, matching: .videos)
    .onChange(of: pickedItem) { _, newItem in
      guard let newItem else { return }
      pickedItem = nil
      isPreparing = true
      Task { await importPicked(newItem) }
    }
    .onChange(of: rowState?.attachment.status) { _, status in
      // Once the manager owns a row, its status drives the UI; drop the
      // local placeholder so error/cancel paths can restore the pick buttons.
      if status != nil { isPreparing = false }
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $showingCamera) {
        CameraRecorderView(
          maxDurationSeconds: videoViewModel.maxDurationSeconds,
          isPresented: $showingCamera,
          onPicked: { url in
            isPreparing = true
            Task {
              await attach(sourceURL: url)
            }
          },
          onFailure: {
            videoViewModel.reportVideoProcessingFailure()
          }
        )
        .ignoresSafeArea()
      }
      .fullScreenCover(item: $libraryVideoToTrim) { movie in
        VideoTrimmerView(
          sourceURL: movie.url,
          maxDurationSeconds: videoViewModel.maxDurationSeconds,
          onSave: { editedURL in
            libraryVideoToTrim = nil
            isPreparing = true
            Task { await attach(sourceURL: editedURL) }
          },
          onCancel: {
            libraryVideoToTrim = nil
          },
          onFailure: {
            libraryVideoToTrim = nil
            videoViewModel.reportVideoProcessingFailure()
          }
        )
        .ignoresSafeArea()
      }
    #endif
  }

  private var presentationState: VideoAttachmentV3State {
    if let status = rowState?.attachment.status {
      switch status {
      case .pending, .uploading:
        return .attached(cameraAvailable: cameraAvailable, canDelete: true, delivered: false)
      case .uploaded:
        return .attached(cameraAvailable: cameraAvailable, canDelete: true, delivered: true)
      case .failed:
        return .failed
      }
    }
    if isPreparing {
      return .attached(cameraAvailable: cameraAvailable, canDelete: false, delivered: false)
    }
    return .choices(cameraAvailable: cameraAvailable)
  }

  private var cameraAvailable: Bool {
    #if os(iOS)
      CameraRecorderView.isAvailable
    #else
      false
    #endif
  }
}

enum VideoAttachmentV3State: Equatable {
  case choices(cameraAvailable: Bool)
  case attached(cameraAvailable: Bool, canDelete: Bool, delivered: Bool)
  case failed
}

@available(iOS 17.0, macOS 14.0, *)
struct VideoAttachmentV3Controls: View {
  let state: VideoAttachmentV3State
  let onCamera: @MainActor () -> Void
  let onLibrary: @MainActor () -> Void
  let onCancel: @MainActor () -> Void
  let onRetry: @MainActor () -> Void
  let onDelete: @MainActor () -> Void

  var body: some View {
    switch state {
    case .choices(let cameraAvailable):
      HStack(spacing: MeetPRSpacing.point10) {
        actionButton(
          "拍摄",
          systemImage: "video",
          isEnabled: cameraAvailable,
          action: onCamera
        )
        actionButton("相册", systemImage: "photo", action: onLibrary)
      }

    case .attached(let cameraAvailable, let canDelete, let delivered):
      // On-demand confirmation only inside the edit sheet (David 2026-08-06):
      // the glanceable surfaces stay free of upload chrome.
      VStack(alignment: .trailing, spacing: MeetPRSpacing.point7) {
        HStack(spacing: MeetPRSpacing.point10) {
          actionButton("重拍", systemImage: "video", isEnabled: cameraAvailable, action: onCamera)
          actionButton("更换", systemImage: "photo", action: onLibrary)
          actionButton("删除", systemImage: "trash", action: onDelete)
            .disabled(!canDelete)
        }
        Label(
          delivered ? "已送达教练" : "还在路上",
          systemImage: delivered ? "checkmark.circle" : "arrow.up.circle.dotted"
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .regular))
        .foregroundStyle(Color.MeetPR.goldRGB.opacity(0.45))
      }

    case .failed:
      HStack(spacing: MeetPRSpacing.space2) {
        Label("上传失败", systemImage: "exclamationmark.triangle.fill")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
          .foregroundStyle(Color.MeetPR.danger)
        actionButton("重试", systemImage: "arrow.clockwise", action: onRetry)
        actionButton("删除", systemImage: "trash", action: onDelete)
      }
    }
  }

  private func actionButton(
    _ title: String,
    systemImage: String,
    isEnabled: Bool = true,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.point7) {
        Image(systemName: systemImage)
          .font(.system(size: MeetPRFontMetrics.size20, weight: .regular))
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
      }
      .foregroundStyle(Color.MeetPR.goldRGB.opacity(isEnabled ? 0.72 : 0.30))
      .padding(.horizontal, MeetPRSpacing.point15)
      .padding(.vertical, MeetPRSpacing.space2)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.goldRGB.opacity(isEnabled ? 0.24 : 0.12), lineWidth: 1)
      }
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(!isEnabled)
  }
}

// MARK: - Actions

extension VideoAttachmentSection {
  private func requestPick(_ source: PendingSource) {
    onWillPick?()
    if videoViewModel.hasConsented {
      present(source)
    } else {
      pendingSource = source
      showingConsent = true
    }
  }

  private func present(_ source: PendingSource) {
    switch source {
    case .camera:
      showingCamera = true
    case .library:
      showingPhotosPicker = true
    }
  }

  private func importPicked(_ item: PhotosPickerItem) async {
    guard let movie = try? await item.loadTransferable(type: PickedVideo.self) else {
      // Load failed or the user backed out: no row will arrive, so clear the
      // placeholder to bring the pick buttons back.
      isPreparing = false
      return
    }
    #if os(iOS)
      if UIVideoEditorController.canEditVideo(atPath: movie.url.path) {
        // Trim before upload; the spinner yields to the editor, and the
        // save/cancel/failure callbacks own the next state.
        isPreparing = false
        libraryVideoToTrim = movie
        return
      }
    #endif
    await attach(sourceURL: movie.url)
  }

  private func attach(sourceURL: URL) async {
    guard let setLogID = await ensureSetLogID() else {
      // Ownership never transfers to the upload manager on this path: both the
      // camera copy and the library import live in tmp and would leak here.
      try? FileManager.default.removeItem(at: sourceURL)
      videoViewModel.reportVideoProcessingFailure()
      isPreparing = false
      return
    }
    await videoViewModel.attach(
      sourceURL: sourceURL,
      setLogID: setLogID,
      studentID: studentID,
      trainingDate: trainingDate
    )
    // `enqueue` sets `lastErrorMessage` synchronously on failure (e.g. the
    // clip exceeds the duration limit) and never broadcasts a row, so the
    // status onChange won't fire — restore the buttons here instead.
    if videoViewModel.lastErrorMessage != nil {
      isPreparing = false
    }
  }

  private func ensureSetLogID() async -> UUID? {
    if let resolvedSetLogID { return resolvedSetLogID }
    let resolved = await resolveSetLogID()
    resolvedSetLogID = resolved
    return resolved
  }

  private func retryAttachment() {
    guard let setLogID = resolvedSetLogID else { return }
    Task { await videoViewModel.retry(setLogID: setLogID) }
  }

  private func removeAttachment() {
    guard let setLogID = resolvedSetLogID else { return }
    Task { await videoViewModel.remove(setLogID: setLogID) }
  }
}

/// File-URL transferable for PhotosPicker video items; the received file is
/// copied into tmp so it outlives the picker session.
struct PickedVideo: Identifiable, Transferable {
  let id = UUID()
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { movie in
      SentTransferredFile(movie.url)
    } importing: { received in
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension)")
      try FileManager.default.copyItem(at: received.file, to: destination)
      return PickedVideo(url: destination)
    }
  }
}
