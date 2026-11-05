import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI

struct VideoMissingFileHost: ViewModifier {
  let model: VideoAttachmentViewModel
  var enabled = true
  let context: (VideoAttachment) -> String
  var onRestored: () async -> Void = {}

  func body(content: Content) -> some View {
    content.sheet(
      item: Binding(
        get: { enabled ? model.missingAttachment : nil },
        set: { if $0 == nil { model.missingAttachment = nil } }
      )
    ) { record in
      VideoMissingFileSheet(
        record: record, context: context(record), model: model, onRestored: onRestored)
    }
  }
}

private struct VideoMissingFileSheet: View {
  let record: VideoAttachment
  let context: String
  let model: VideoAttachmentViewModel
  let onRestored: () async -> Void
  @State private var item: PhotosPickerItem?
  @State private var isImporting = false
  @State private var trim: VideoTrimSession?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
      Text(context).font(.footnote).foregroundStyle(Color.MeetPR.textSecondary)
      Label(
        StudentStrings.localized(.videoMissingTitle), systemImage: "exclamationmark.triangle.fill"
      )
      .font(.title3.bold()).foregroundStyle(Color.MeetPR.danger)
      Text(StudentStrings.localized(.videoMissingBody))
        .font(.body).fixedSize(horizontal: false, vertical: true)
      PhotosPicker(selection: $item, matching: .videos) {
        Text(StudentStrings.localized(.videoPickAgain))
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.borderedProminent).tint(Color.MeetPR.goldCTA)
      .disabled(isImporting)
      if let error = model.lastErrorMessage {
        Text(error).font(.footnote).foregroundStyle(Color.MeetPR.danger)
      }
      Button(StudentStrings.localized(.videoLeaveForNow)) { model.missingAttachment = nil }
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .padding(MeetPRSpacing.space5)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .onChange(of: item) { _, selected in
      guard let selected else { return }
      item = nil
      isImporting = true
      Task { await importVideo(selected) }
    }
    #if os(iOS)
      .fullScreenCover(item: $trim) { session in VideoTrimView(session: session) }
    #endif
  }

  private func importVideo(_ item: PhotosPickerItem) async {
    do {
      guard let movie = try await item.loadTransferable(type: PickedVideo.self) else {
        isImporting = false
        return
      }
      #if os(iOS)
        trim = VideoTrimSession(
          sourceURL: movie.url, maxDurationSeconds: model.maxDurationSeconds,
          onSave: { url in
            trim = nil
            Task { await restore(url) }
          },
          onCancel: {
            trim = nil
            isImporting = false
          },
          onFailure: {
            trim = nil
            isImporting = false
            model.reportVideoProcessingFailure()
          })
      #else
        await restore(movie.url)
      #endif
    } catch {
      isImporting = false
      model.reportVideoProcessingFailure()
    }
  }

  private func restore(_ url: URL) async {
    if await model.restoreMissingVideo(record, sourceURL: url) { await onRestored() }
    isImporting = false
  }
}
