import ChatUI
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Full-screen coach workbench for the cross-student pending-video queue.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoFeedbackDetailView: View {
  private let viewModel: CoachVideoQueueViewModel
  private let trainingLogs: any StudentTrainingLogRepository
  private let markerRepository: any VideoMarkerRepository
  private let onSent: () -> Void

  @Environment(\.coachNow) private var now
  @Environment(\.coachVideoBadgeName) private var coachName
  @Environment(\.dismiss) private var dismiss
  @State private var detailModel: VideoFeedbackDetailModel
  @State private var text = ""
  @State private var sending = false
  @State private var currentSeconds = 0.0
  @State private var markerDraft: VideoMarkerDraft?
  @State private var selectedAnnotationMarker: VideoMarker?

  init(
    item: PendingVideoItem,
    viewModel: CoachVideoQueueViewModel,
    trainingLogs: any StudentTrainingLogRepository,
    markerRepository: any VideoMarkerRepository,
    onSent: @escaping () -> Void = {}
  ) {
    self.viewModel = viewModel
    self.trainingLogs = trainingLogs
    self.markerRepository = markerRepository
    self.onSent = onSent
    _detailModel = State(initialValue: VideoFeedbackDetailModel(item: item))
  }

  var body: some View {
    VStack(spacing: 0) {
      VideoFeedbackHeader(
        studentName: detailModel.currentItem.studentDisplayName,
        exerciseName: detailModel.currentItem.exerciseName.map {
          CoachLocalization.exerciseName($0)
        }
          ?? CoachVideoFeedbackStrings.trainingVideo,
        meta: headerMeta,
        queuePosition: queuePositionText,
        dismiss: dismiss.callAsFunction
      )

      ScrollView {
        VStack(spacing: MeetPRSpacing.space3) {
          VideoFeedbackPlayerCard(
            itemID: detailModel.currentItem.id,
            playbackURL: detailModel.playbackURL,
            isLoading: detailModel.isResolvingPlayback,
            hasError: detailModel.playbackError,
            currentSeconds: $currentSeconds,
            selectedAnnotationMarker: $selectedAnnotationMarker,
            markers: detailModel.markers,
            badge: videoBadge,
            refreshURL: { try await viewModel.playbackURL(videoID: $0) },
            retry: retryPlayback,
            addMarker: addMarkerAction,
            refreshMarkers: refreshMarkers
          )

          if let markers = detailModel.markers, !markers.isEmpty {
            VideoMarkerList(
              markers: markers,
              delete: deleteMarker,
              selectAnnotation: { selectedAnnotationMarker = $0 }
            )
          }

          if detailModel.markersFailed {
            markerFailureRow(CoachVideoFeedbackStrings.markersLoadFailed)
          }

          if let failure = detailModel.markerActionFailure {
            markerFailureRow(
              failure == .save
                ? CoachVideoFeedbackStrings.markerSaveFailed
                : CoachVideoFeedbackStrings.markerDeleteFailed
            )
          }

          VideoSetInfoStatusView(state: detailModel.setInfoState)

          VideoFeedbackComposer(
            text: $text,
            studentName: detailModel.currentItem.studentDisplayName,
            send: send
          )

          if let bannerMessage = viewModel.bannerMessage {
            Text(bannerMessage)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.danger)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Button(action: skip) {
            Text(CoachVideoFeedbackStrings.skip)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textPrimary)
              .frame(maxWidth: .infinity)
              .padding(MeetPRSpacing.point14)
              .contentShape(.capsule)
          }
          .buttonStyle(PressScaleButtonStyle())
          .overlay {
            Capsule()
              .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
          }
          .accessibilityIdentifier("coach.video.skip")
          .disabled(sending)
        }
        .padding(.horizontal, MeetPRSpacing.point18)
        .padding(.top, MeetPRSpacing.point14)
        .padding(.bottom, MeetPRSpacing.point26)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .hideNavigationBar()
    .task(id: detailModel.currentItem.id) {
      currentSeconds = 0
      selectedAnnotationMarker = nil
      await detailModel.prepare(
        videoQueue: viewModel,
        trainingLogs: trainingLogs,
        markerRepository: markerRepository
      )
    }
    .onChange(of: detailModel.markers) { _, markers in
      // A deleted or refreshed-away marker must not keep showing its stale
      // signed URL; a replaced one re-points at the fresh instance.
      guard let selected = selectedAnnotationMarker else { return }
      selectedAnnotationMarker = markers?.first { $0.id == selected.id }
    }
    .sheet(item: $markerDraft) { draft in
      VideoMarkerEditor(draft: draft, save: saveMarker)
    }
    .accessibilityIdentifier("coach.video.feedbackWorkbench")
  }

  static func sizeText(_ sizeBytes: Int64) -> String {
    let megabytes = Double(sizeBytes) / 1_048_576
    let value =
      megabytes >= 10
      ? megabytes.formatted(.number.precision(.fractionLength(0)))
      : megabytes.formatted(.number.precision(.fractionLength(1)))
    return CoachVideoFeedbackStrings.sizeMegabytes(value)
  }

  private var setText: String {
    guard let setInfo = detailModel.setInfo else {
      return CoachVideoFeedbackStrings.trainingVideo
    }
    return CoachVideoFeedbackStrings.setNumber(setInfo.displaySetNumber)
  }

  private var headerMeta: String {
    CoachVideoFeedbackStrings.headerMeta(
      setText: setText,
      relativeTime: CoachStudentFormatting.relativeText(
        detailModel.currentItem.uploadedAt,
        now: now
      )
    )
  }

  private var queuePositionText: String? {
    let items = viewModel.items
    guard
      let position = VideoFeedbackQueueNavigator.position(
        of: detailModel.currentItem.id,
        in: items
      )
    else {
      return nil
    }
    return CoachVideoFeedbackStrings.queuePosition(
      index: position.displayIndex,
      total: position.total
    )
  }

  private var canSend: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
  }

  private var addMarkerAction: (() -> Void)? {
    guard detailModel.markers != nil else { return nil }
    return {
      markerDraft = VideoMarkerDraft(
        timeMilliseconds: max(0, Int((currentSeconds * 1_000).rounded()))
      )
    }
  }

  private func retryPlayback() {
    Task {
      await detailModel.loadPlayback(using: viewModel)
    }
  }

  private func refreshMarkers() async {
    await detailModel.reloadMarkers(using: markerRepository)
  }

  private func skip() {
    let items = viewModel.items
    guard
      let next = VideoFeedbackQueueNavigator.nextItem(
        after: detailModel.currentItem.id,
        in: items
      )
    else {
      dismiss()
      return
    }
    show(next)
  }

  private func send() {
    guard canSend else { return }
    let sentItem = detailModel.currentItem
    // 记下「发送时排在它后面那一段」的**身份**,不是索引:发送等待期间若刷新落地
    // 并前插/重排,旧索引会指向另一段(review-loop 2026-07-30)。
    let successorID = VideoFeedbackQueueNavigator.nextItem(
      after: sentItem.id,
      in: viewModel.items
    )?.id
    let submittedText = text
    sending = true
    Task {
      defer { sending = false }
      guard await viewModel.sendFeedback(for: sentItem, text: submittedText) else { return }
      onSent()
      guard
        let next = VideoFeedbackQueueNavigator.itemAfterSend(
          preferring: successorID,
          in: viewModel.items
        )
      else {
        dismiss()
        return
      }
      show(next)
    }
  }

  private func show(_ item: PendingVideoItem) {
    text = ""
    currentSeconds = 0
    selectedAnnotationMarker = nil
    detailModel.select(item)
  }

  private func saveMarker(_ draft: VideoMarkerDraft) {
    markerDraft = nil
    Task {
      // Level stays single-tier in the UI (⚖️ 2026-07-31 David); the wire
      // field remains and always carries the backend default.
      await detailModel.createMarker(
        timeMilliseconds: draft.timeMilliseconds,
        level: .info,
        note: draft.note,
        using: markerRepository
      )
    }
  }

  private func deleteMarker(_ marker: VideoMarker) {
    Task {
      await detailModel.deleteMarker(marker, using: markerRepository)
    }
  }
}

extension VideoFeedbackDetailView {
  fileprivate var videoBadge: VideoBadgeInfo {
    CoachVideoBadgeResolver.pendingVideo(
      detailModel.currentItem,
      setInfo: detailModel.setInfo,
      coachName: coachName
    )
  }

  fileprivate func markerFailureRow(_ message: String) -> some View {
    Text(message)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.danger)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct VideoMarkerDraft: Identifiable {
  let id = UUID()
  let timeMilliseconds: Int
  var note = ""
}

@available(iOS 17.0, macOS 14.0, *)
private struct VideoMarkerEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: VideoMarkerDraft
  let save: (VideoMarkerDraft) -> Void

  init(draft: VideoMarkerDraft, save: @escaping (VideoMarkerDraft) -> Void) {
    _draft = State(initialValue: draft)
    self.save = save
  }

  var body: some View {
    NavigationStack {
      Form {
        LabeledContent(
          CoachVideoFeedbackStrings.markerTime,
          value: FeedbackVideoPlayerView.timeText(Double(draft.timeMilliseconds) / 1_000)
        )
        TextField(
          CoachVideoFeedbackStrings.markerNote,
          text: $draft.note,
          axis: .vertical
        )
        .lineLimit(3...6)
        .onChange(of: draft.note) { _, note in
          if note.count > 500 {
            draft.note = String(note.prefix(500))
          }
        }
      }
      .navigationTitle(CoachVideoFeedbackStrings.addMarker)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(CoachVideoFeedbackStrings.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(CoachVideoFeedbackStrings.save) { save(draft) }
        }
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct VideoMarkerList: View {
  let markers: [VideoMarker]
  let delete: (VideoMarker) -> Void
  let selectAnnotation: (VideoMarker) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(CoachVideoFeedbackStrings.markerCount(markers.count))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)

      VStack(spacing: 0) {
        ForEach(markers) { marker in
          HStack(spacing: MeetPRSpacing.point11) {
            if marker.annotationURL != nil {
              Button {
                selectAnnotation(marker)
              } label: {
                VideoMarkerRowLabel(marker: marker)
              }
              .accessibilityIdentifier("coach.video.marker.annotation")
            } else {
              VideoMarkerRowLabel(marker: marker)
            }
            Button(role: .destructive) {
              delete(marker)
            } label: {
              Image(systemName: "trash")
            }
            .accessibilityLabel(CoachVideoFeedbackStrings.deleteMarker)
          }
          .padding(.horizontal, MeetPRSpacing.space4)
          .padding(.vertical, MeetPRSpacing.point13)

          if marker.id != markers.last?.id {
            Rectangle()
              .fill(Color.MeetPR.borderHairline)
              .frame(height: MeetPRSpacing.point1)
          }
        }
      }
      .meetPRCardSurface(.card)
    }
  }
}
