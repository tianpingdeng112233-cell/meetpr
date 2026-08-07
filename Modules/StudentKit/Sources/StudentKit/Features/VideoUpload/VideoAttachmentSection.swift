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
  @State private var libraryVideoToTrim: VideoTrimSession?
  @State private var activeLibraryTrimSession: VideoTrimSession?
  @State private var pendingSource: PendingSource?
  @State private var playbackPresentation: SetVideoPlaybackPresentation?
  @State private var playbackErrorMessage: String?
  @State private var isLoadingPlayback = false
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
        if hasPlayableAttachment {
          Button(action: playAttachment) {
            Label("视频", systemImage: "play.circle.fill")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .medium))
              .foregroundStyle(Color.MeetPR.textPrimary)
          }
          .buttonStyle(.plain)
          .disabled(isLoadingPlayback)
        } else {
          Text("视频")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .medium))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
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
      if let playbackErrorMessage {
        HStack(spacing: MeetPRSpacing.space2) {
          Text(playbackErrorMessage)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.danger)
          Button("重试", action: playAttachment)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldRGB.opacity(0.72))
            .disabled(isLoadingPlayback)
        }
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
      .fullScreenCover(item: $playbackPresentation) { presentation in
        playbackView(for: presentation)
      }
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
      }
      .fullScreenCover(
        item: $libraryVideoToTrim,
        onDismiss: finishLibraryTrimPresentation
      ) { session in
        VideoTrimmerView(session: session)
        .ignoresSafeArea()
      }
    #else
      .sheet(item: $playbackPresentation) { presentation in
        playbackView(for: presentation)
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

  private var hasPlayableAttachment: Bool {
    guard rowState != nil else { return false }
    if case .attached = presentationState {
      return true
    }
    return false
  }

  private func playbackView(
    for presentation: SetVideoPlaybackPresentation
  ) -> SetVideoPlaybackView {
    SetVideoPlaybackView(
      attachmentID: presentation.attachmentID,
      source: presentation.source,
      refreshRemoteURL: { attachmentID in
        try await videoViewModel.freshRemotePlaybackURL(attachmentID: attachmentID)
      }
    )
  }
}

private struct SetVideoPlaybackPresentation: Identifiable {
  let id = UUID()
  let attachmentID: UUID
  let source: VideoAttachmentPlaybackSource
}

// MARK: - Actions

extension VideoAttachmentSection {
  private func playAttachment() {
    guard !isLoadingPlayback, let attachmentID = rowState?.attachment.id else { return }
    isLoadingPlayback = true
    playbackErrorMessage = nil
    Task {
      defer { isLoadingPlayback = false }
      do {
        guard
          let source = try await videoViewModel.playbackSource(attachmentID: attachmentID)
        else {
          guard rowState?.attachment.id == attachmentID else { return }
          playbackErrorMessage = "视频暂时无法播放,请重试"
          return
        }
        guard rowState?.attachment.id == attachmentID else { return }
        playbackPresentation = SetVideoPlaybackPresentation(
          attachmentID: attachmentID,
          source: source
        )
      } catch {
        guard rowState?.attachment.id == attachmentID else { return }
        playbackErrorMessage = "视频加载失败,请检查网络后重试"
      }
    }
  }

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
        let session = VideoTrimSession(
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
        activeLibraryTrimSession = session
        libraryVideoToTrim = session
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

  private func finishLibraryTrimPresentation() {
    activeLibraryTrimSession?.cancelled()
    activeLibraryTrimSession = nil
    libraryVideoToTrim = nil
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
