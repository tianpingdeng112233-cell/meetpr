import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// One student's pending 训练视频, opened from the inbox (spec 042 D1). Videos
/// are grouped by training day (newest first) — a single day can hold squat +
/// bench + deadlift, each set's clip listed under it. Tapping a clip opens the
/// global player + text-feedback workbench. Emptying this student's list only
/// pops back to the inbox after the global workbench closes.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentPendingVideosView: View {
  private let studentID: UUID
  private let studentName: String
  private let viewModel: CoachVideoQueueViewModel
  private let trainingLogs: any StudentTrainingLogRepository
  private let markerRepository: any VideoMarkerRepository

  @State private var videoDetailTarget: PendingVideoItem?
  @Environment(\.dismiss) private var dismiss

  init(
    studentID: UUID,
    studentName: String,
    viewModel: CoachVideoQueueViewModel,
    trainingLogs: any StudentTrainingLogRepository = EmptyStudentTrainingLogRepository(),
    markerRepository: any VideoMarkerRepository = InMemoryVideoMarkerRepository()
  ) {
    self.studentID = studentID
    self.studentName = studentName
    self.viewModel = viewModel
    self.trainingLogs = trainingLogs
    self.markerRepository = markerRepository
  }

  private var sections: [PendingVideoDaySection] {
    CoachVideoQueueViewModel.daySections(viewModel.items(for: studentID))
  }

  var body: some View {
    ScrollView {
      switch contentState {
      case .loading:
        ProgressView(CoachInboxStrings.loading)
          .tint(Color.MeetPR.gold500)
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.point32)
      case .failed:
        ContentUnavailableView(
          CoachInboxStrings.loadFailed,
          systemImage: "exclamationmark.triangle"
        )
        .padding(.vertical, MeetPRSpacing.point18)
      case .empty:
        ContentUnavailableView(
          CoachVideoFeedbackStrings.noPendingVideos,
          systemImage: "checkmark.circle",
          description: Text(CoachVideoFeedbackStrings.noPendingVideosSubtitle)
        )
        .padding(.vertical, MeetPRSpacing.point18)
      case .content:
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          ForEach(sections) { section in
            daySection(section)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.vertical, MeetPRSpacing.point14)
      }
    }
    .scrollIndicators(.hidden)
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .coachFullScreenDestination()
    .navigationTitle(studentName)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    #if os(iOS)
      .fullScreenCover(item: $videoDetailTarget, onDismiss: dismissIfEmpty) { item in
        VideoFeedbackDetailView(
          item: item,
          viewModel: viewModel,
          trainingLogs: trainingLogs,
          markerRepository: markerRepository
        )
      }
    #else
      .sheet(item: $videoDetailTarget, onDismiss: dismissIfEmpty) { item in
        VideoFeedbackDetailView(
          item: item,
          viewModel: viewModel,
          trainingLogs: trainingLogs,
          markerRepository: markerRepository
        )
      }
    #endif
    .onChange(of: sections.isEmpty) { _, isEmpty in
      if Self.shouldDismissStudentList(
        isEmpty: isEmpty,
        isDetailPresented: videoDetailTarget != nil
      ) {
        dismiss()
      }
    }
  }

  private var contentState: StudentPendingVideosContentState {
    StudentPendingVideosContentState.resolve(
      loadState: viewModel.state,
      sectionsAreEmpty: sections.isEmpty
    )
  }

  static func shouldDismissStudentList(
    isEmpty: Bool,
    isDetailPresented: Bool
  ) -> Bool {
    isEmpty && !isDetailPresented
  }

  private func daySection(_ section: PendingVideoDaySection) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(CoachStudentFormatting.fullDateText(section.day))
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textTertiary)
      ForEach(section.items) { item in
        videoRow(item)
      }
    }
  }

  private func videoRow(_ item: PendingVideoItem) -> some View {
    Button {
      videoDetailTarget = item
    } label: {
      HStack(spacing: MeetPRSpacing.base) {
        ZStack {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .fill(Color.MeetPR.bgStack)
            .frame(width: 52, height: 52)
          Image(systemName: "play.rectangle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.MeetPR.gold500)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(
            item.exerciseName.map { CoachLocalization.exerciseName($0) }
              ?? CoachVideoFeedbackStrings.trainingVideo
          )
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          Text(rowMeta(item))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
        Spacer(minLength: MeetPRSpacing.sm)
        Image(systemName: "chevron.right")
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.textDisabled)
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .meetPRCardSurface(.card)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      CoachVideoFeedbackStrings.rowAccessibility(
        exerciseName: item.exerciseName.map { CoachLocalization.exerciseName($0) }
          ?? CoachVideoFeedbackStrings.trainingVideo
      )
    )
    .accessibilityIdentifier("coach.video.row.\(item.id.uuidString)")
  }

  private func rowMeta(_ item: PendingVideoItem) -> String {
    CoachStudentFormatting.timeText(item.uploadedAt) + " · "
      + VideoFeedbackDetailView.sizeText(item.sizeBytes)
  }

  private func dismissIfEmpty() {
    if sections.isEmpty { dismiss() }
  }
}

enum StudentPendingVideosContentState: Equatable {
  case loading
  case failed
  case empty
  case content

  static func resolve(
    loadState: CoachVideoQueueViewModel.LoadState,
    sectionsAreEmpty: Bool
  ) -> StudentPendingVideosContentState {
    switch loadState {
    case .idle, .loading:
      return .loading
    case .failed:
      return sectionsAreEmpty ? .failed : .content
    case .loaded:
      return sectionsAreEmpty ? .empty : .content
    }
  }
}
