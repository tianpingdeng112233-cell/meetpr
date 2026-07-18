import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "附视频" block inside SetEntrySheet (spec 027): pick from the photo
/// library or record with the camera, then watch upload progress with retry /
/// delete affordances. The first attach shows the coach-visibility consent
/// dialog.
@available(iOS 17.0, macOS 14.0, *)
struct VideoAttachmentSection: View {
  let studentID: UUID
  let videoViewModel: VideoAttachmentViewModel
  /// Set-log id when the row was already logged; nil until first commit.
  let initialSetLogID: UUID?
  /// Lazily creates the set log (preserving completion state) so a video can
  /// attach to a not-yet-completed set.
  let resolveSetLogID: @MainActor () async -> UUID?

  @State private var resolvedSetLogID: UUID?
  @State private var showingConsent = false
  @State private var showingPhotosPicker = false
  @State private var showingCamera = false
  @State private var pickedItem: PhotosPickerItem?
  @State private var libraryVideoToTrim: PickedVideo?
  @State private var pendingSource: PendingSource?

  private enum PendingSource {
    case camera
    case library
  }

  init(
    studentID: UUID,
    videoViewModel: VideoAttachmentViewModel,
    initialSetLogID: UUID?,
    resolveSetLogID: @escaping @MainActor () async -> UUID?
  ) {
    self.studentID = studentID
    self.videoViewModel = videoViewModel
    self.initialSetLogID = initialSetLogID
    self.resolveSetLogID = resolveSetLogID
    _resolvedSetLogID = State(initialValue: initialSetLogID)
  }

  private var rowState: VideoAttachmentViewModel.RowState? {
    resolvedSetLogID.flatMap { videoViewModel.rowStates[$0] }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Text("视频")
          .font(.body)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        content
      }
      if let message = videoViewModel.lastErrorMessage {
        Text(message)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
    }
    .padding(14)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
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
      Task { await importPicked(newItem) }
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $showingCamera) {
        CameraVideoPicker(
          maxDurationSeconds: videoViewModel.maxDurationSeconds,
          onPicked: { url in
            Task { await attach(sourceURL: url) }
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

  @ViewBuilder
  private var content: some View {
    switch rowState?.attachment.status {
    case .none:
      pickButtons
    case .pending:
      statusRow(text: "处理中…", showsSpinner: true)
    case .uploading:
      uploadingRow
    case .uploaded:
      uploadedRow
    case .failed:
      failedRow
    }
  }

  private var pickButtons: some View {
    HStack(spacing: 10) {
      #if os(iOS)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
          actionChip("拍摄", systemImage: "video") { requestPick(.camera) }
        }
      #endif
      actionChip("相册", systemImage: "photo.on.rectangle") { requestPick(.library) }
    }
  }

  private var uploadingRow: some View {
    HStack(spacing: 10) {
      ProgressView(value: rowState?.progress ?? 0)
        .frame(width: 90)
      Text("\(Int((rowState?.progress ?? 0) * 100))%")
        .font(.caption.monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgSecondary)
      cancelButton
    }
  }

  private var uploadedRow: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Color.MeetPR.green)
      Text("已上传")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      actionChip("删除", systemImage: "trash") { removeAttachment() }
    }
  }

  private var failedRow: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.MeetPR.brandRed)
      Text("上传失败")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      actionChip("重试", systemImage: "arrow.clockwise") { retryAttachment() }
      actionChip("删除", systemImage: "trash") { removeAttachment() }
    }
  }

  private func statusRow(text: String, showsSpinner: Bool) -> some View {
    HStack(spacing: 10) {
      if showsSpinner {
        ProgressView()
          .controlSize(.small)
      }
      Text(text)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      cancelButton
    }
  }

  private var cancelButton: some View {
    actionChip("取消", systemImage: "xmark") { removeAttachment() }
  }

  private func actionChip(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.caption.bold())
        .foregroundStyle(Color.MeetPR.brandRed)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.MeetPR.brandRedSoft)
        .clipShape(.capsule)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Actions

  private func requestPick(_ source: PendingSource) {
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
      videoViewModel.reportVideoProcessingFailure()
      return
    }
    #if os(iOS)
      if UIVideoEditorController.canEditVideo(atPath: movie.url.path) {
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
      return
    }
    await videoViewModel.attach(sourceURL: sourceURL, setLogID: setLogID, studentID: studentID)
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
