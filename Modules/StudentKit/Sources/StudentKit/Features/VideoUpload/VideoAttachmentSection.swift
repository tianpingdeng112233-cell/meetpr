import ChatUI
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
  let draftID: UUID
  let slot: VideoAttachment.SetSlot?
  let studentID: UUID
  let trainingDate: Date
  let videoViewModel: VideoAttachmentViewModel
  let badge: VideoBadgeInfo?
  let playback: SetEntryVideoPlayer
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
  @State private var playbackErrorMessage: String?
  @State private var isLoadingPlayback = false
  @State private var playbackLoadRevision = 0
  /// True from the moment a video is chosen until the upload manager owns a
  /// row for it. Covers the otherwise feedback-less window where the picked
  /// file is copied from the picker, until `enqueue` emits its first `.pending` event.
  @State private var isPreparing = false
  @State private var importTask: Task<Void, Never>?

  private enum PendingSource {
    case camera
    case library
  }

  init(
    draftID: UUID,
    slot: VideoAttachment.SetSlot? = nil,
    studentID: UUID,
    trainingDate: Date,
    videoViewModel: VideoAttachmentViewModel,
    badge: VideoBadgeInfo? = nil,
    playback: SetEntryVideoPlayer,
    initialSetLogID: UUID?,
    resolveSetLogID: @escaping @MainActor () async -> UUID?,
    onWillPick: (() -> Void)? = nil
  ) {
    self.draftID = draftID
    self.slot = slot
    self.studentID = studentID
    self.trainingDate = trainingDate
    self.videoViewModel = videoViewModel
    self.badge = badge
    self.playback = playback
    self.initialSetLogID = initialSetLogID
    self.resolveSetLogID = resolveSetLogID
    self.onWillPick = onWillPick
    _resolvedSetLogID = State(initialValue: initialSetLogID)
  }

  private var rowState: VideoAttachmentViewModel.RowState? {
    videoViewModel.pendingRowState(draftID: draftID, trainingDate: trainingDate, slot: slot)
      ?? (resolvedSetLogID ?? initialSetLogID).flatMap { videoViewModel.rowStates[$0] }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      if rowState != nil {
        // Keep the inline footprint while expanded so the scroll offset is not clamped.
        SetEntryVideoPlayerView(
          playback: playback, badge: badge, isInline: true, retry: retryPlayback
        )
        .opacity(playback.state.isExpanded ? 0 : 1)
        .allowsHitTesting(!playback.state.isExpanded)
        VideoAttachmentV3Controls(
          state: presentationState,
          onCamera: { requestPick(.camera) }, onLibrary: { requestPick(.library) },
          onCancel: removeAttachment, onRetry: retryAttachment, onDelete: removeAttachment)
      } else {
        HStack(spacing: MeetPRSpacing.space3) {
          Text(StudentStrings.localized(.videoAttachmentSection001))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .medium))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          VideoAttachmentV3Controls(
            state: presentationState,
            onCamera: { requestPick(.camera) }, onLibrary: { requestPick(.library) },
            onCancel: removeAttachment, onRetry: retryAttachment, onDelete: removeAttachment)
        }
      }
      if let message = videoViewModel.processingFailureMessage(forDraftID: draftID) {
        Text(message)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.danger)
      }
      if let playbackErrorMessage {
        HStack(spacing: MeetPRSpacing.space2) {
          Text(playbackErrorMessage)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.danger)
          Button(StudentStrings.localized(.videoAttachmentSection002), action: playAttachment)
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
    .modifier(
      VideoMissingFileHost(
        model: videoViewModel,
        context: { _ in
          [
            badge?.exerciseName,
            badge?.setOrdinal.map { HistoryEntriesView.setLabel(forZeroBasedIndex: $0 - 1) },
          ].compactMap { $0 }.joined(
            separator: " · ")
        },
        onRestored: {
          if let record = rowState?.attachment, record.pendingDraftID != nil {
            await videoViewModel.retryPending(
              setLogID: record.setLogID, resolveSetLogID: { await ensureSetLogID() })
          }
        })
    )
    .photosPicker(
      isPresented: $showingPhotosPicker, selection: $pickedItem, matching: .videos,
      preferredItemEncoding: .current
    )
    .onChange(of: pickedItem) { _, newItem in
      guard let newItem else { return }
      pickedItem = nil
      isPreparing = true
      importTask = Task { await importPicked(newItem) }
    }
    .onDisappear { importTask?.cancel() }
    .onChange(of: rowState?.attachment.status) { _, status in
      // Once the manager owns a row, its status drives the UI; drop the
      // local placeholder so error/cancel paths can restore the pick buttons.
      if status != nil { isPreparing = false }
    }
    .task(id: "\(rowState?.attachment.id.uuidString ?? "none")-\(playbackLoadRevision)") {
      guard rowState != nil else {
        playback.stop()
        return
      }
      await loadPlayback()
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
            isPreparing = false
          },
          allDayFlow: true
        )
      }
      .fullScreenCover(
        item: $libraryVideoToTrim,
        onDismiss: finishLibraryTrimPresentation
      ) { session in
        VideoTrimView(session: session, uploadsOnSave: true)
      }
    #endif
  }

  private var presentationState: VideoAttachmentV3State {
    VideoAttachmentV3State.resolve(
      status: rowState.map {
        VideoDeliveryPresentation.hasFailure($0.attachment) ? .failed : $0.attachment.status
      },
      isPreparing: isPreparing,
      cameraAvailable: cameraAvailable
    )
  }

  private var cameraAvailable: Bool {
    #if os(iOS)
      CameraRecorderView.isAvailable
    #else
      false
    #endif
  }

}

// MARK: - Actions

extension VideoAttachmentSection {
  private func playAttachment() {
    playbackLoadRevision += 1
  }

  private func retryPlayback() {
    guard playback.player != nil else {
      playAttachment()
      return
    }
    Task {
      await playback.retry { attachmentID in
        try await videoViewModel.freshRemotePlaybackURL(attachmentID: attachmentID)
      }
    }
  }

  private func loadPlayback() async {
    guard let attachmentID = rowState?.attachment.id else { return }
    isLoadingPlayback = true
    playbackErrorMessage = nil
    defer { isLoadingPlayback = false }
    do {
      guard let source = try await videoViewModel.playbackSource(attachmentID: attachmentID) else {
        guard rowState?.attachment.id == attachmentID else { return }
        playbackErrorMessage = StudentStrings.localized(.videoAttachmentSection003)
        return
      }
      guard !Task.isCancelled, rowState?.attachment.id == attachmentID else { return }
      playback.load(attachmentID: attachmentID, source: source)
    } catch {
      guard !Task.isCancelled, rowState?.attachment.id == attachmentID else { return }
      playbackErrorMessage = StudentStrings.localized(.videoAttachmentSection004)
    }
  }

  private func requestPick(_ source: PendingSource) {
    guard !isPreparing, activeLibraryTrimSession == nil, libraryVideoToTrim == nil else { return }
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
    defer { importTask = nil }
    let movie: PickedVideo?
    do {
      movie = try await item.loadTransferable(type: PickedVideo.self)
    } catch {
      isPreparing = false
      guard !Task.isCancelled else { return }
      VideoProcessingDiagnostics().report(.picker, error: error)
      videoViewModel.reportVideoProcessingFailure()
      return
    }
    guard !Task.isCancelled else {
      if let movie { try? FileManager.default.removeItem(at: movie.url) }
      isPreparing = false
      return
    }
    guard let movie else {
      VideoProcessingDiagnostics().report(.picker, code: .noTransferable)
      videoViewModel.reportVideoProcessingFailure()
      isPreparing = false
      return
    }
    #if os(iOS)
      let session = VideoTrimSession(
        sourceURL: movie.url,
        maxDurationSeconds: videoViewModel.maxDurationSeconds,
        onSave: { editedURL in
          activeLibraryTrimSession = nil
          libraryVideoToTrim = nil
          Task { await attach(sourceURL: editedURL) }
        },
        onCancel: {
          activeLibraryTrimSession = nil
          libraryVideoToTrim = nil
          isPreparing = false
        },
        onFailure: {
          activeLibraryTrimSession = nil
          libraryVideoToTrim = nil
          videoViewModel.reportVideoProcessingFailure()
          isPreparing = false
        }
      )
      activeLibraryTrimSession = session
      libraryVideoToTrim = session
    #else
      await attach(sourceURL: movie.url)
    #endif
  }

  private func attach(sourceURL: URL) async {
    await videoViewModel.attach(
      sourceURL: sourceURL, draftID: draftID, studentID: studentID,
      trainingDate: trainingDate, slot: slot, resolveSetLogID: { await ensureSetLogID() })
    // A local persistence failure may produce no row event. Restore the
    // controls explicitly so the error remains actionable.
    if videoViewModel.processingFailureMessage(forDraftID: draftID) != nil {
      isPreparing = false
    }
  }

  private func finishLibraryTrimPresentation() {
    guard let session = activeLibraryTrimSession else {
      libraryVideoToTrim = nil
      return
    }
    session.cancelled()
    activeLibraryTrimSession = nil
    libraryVideoToTrim = nil
    isPreparing = false
  }

  private func ensureSetLogID() async -> UUID? {
    if let resolvedSetLogID { return resolvedSetLogID }
    let resolved = await resolveSetLogID()
    resolvedSetLogID = resolved
    return resolved
  }

  private func retryAttachment() {
    guard let record = rowState?.attachment else { return }
    Task {
      if record.pendingDraftID != nil {
        await videoViewModel.retryPending(
          setLogID: record.setLogID, resolveSetLogID: { await ensureSetLogID() })
      } else {
        await videoViewModel.retry(setLogID: record.setLogID)
      }
    }
  }

  private func removeAttachment() {
    guard let record = rowState?.attachment else { return }
    Task { await videoViewModel.remove(setLogID: record.setLogID) }
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
