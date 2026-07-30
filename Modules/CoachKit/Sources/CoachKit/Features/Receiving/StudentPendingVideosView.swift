import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// One student's pending 训练视频, opened from the inbox (spec 042 D1). Videos
/// are grouped by training day (newest first) — a single day can hold squat +
/// bench + deadlift, each set's clip listed under it. Tapping a clip opens the
/// player + text-feedback composer; sending drops that clip, and emptying the
/// list pops back to the inbox.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentPendingVideosView: View {
  private let studentID: UUID
  private let studentName: String
  private let viewModel: CoachVideoQueueViewModel

  @State private var videoDetailTarget: PendingVideoItem?
  @Environment(\.dismiss) private var dismiss

  init(studentID: UUID, studentName: String, viewModel: CoachVideoQueueViewModel) {
    self.studentID = studentID
    self.studentName = studentName
    self.viewModel = viewModel
  }

  private var sections: [PendingVideoDaySection] {
    CoachVideoQueueViewModel.daySections(viewModel.items(for: studentID))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        ForEach(sections) { section in
          daySection(section)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .coachFullScreenDestination()
    .navigationTitle(studentName)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .sheet(item: $videoDetailTarget) { item in
      VideoFeedbackDetailView(item: item, viewModel: viewModel)
    }
    .onChange(of: sections.isEmpty) { _, isEmpty in
      // Last clip answered — nothing left for this student, return to the inbox.
      if isEmpty { dismiss() }
    }
  }

  private func daySection(_ section: PendingVideoDaySection) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(CoachStudentFormatting.fullDateText(section.day))
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgSecondary)
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
            .fill(Color.MeetPR.surface2)
            .frame(width: 52, height: 52)
          Image(systemName: "play.rectangle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(item.exerciseName ?? "训练视频")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(rowMeta(item))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        Spacer(minLength: MeetPRSpacing.sm)
        Image(systemName: "chevron.right")
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(Color.MeetPR.border, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(item.exerciseName ?? "训练视频")，点按写反馈")
  }

  private func rowMeta(_ item: PendingVideoItem) -> String {
    CoachStudentFormatting.timeText(item.uploadedAt) + " · "
      + VideoFeedbackDetailView.sizeText(item.sizeBytes)
  }
}
