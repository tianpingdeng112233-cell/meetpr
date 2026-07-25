import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachFeedbackHistoryView: View {
  let feedback: [CoachFeedback]
  let days: [StudentPlanDay]
  let onCompose: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Button(action: onCompose) {
          Label("写反馈", systemImage: "square.and.pencil")
            .font(Font.MeetPR.bodyEmphasis)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeetPRSpacing.point13)
            .foregroundStyle(Color.MeetPR.bgBase)
            .background(Color.MeetPR.textPrimary)
            .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        }

        if feedback.isEmpty {
          ContentUnavailableView("暂无反馈", systemImage: "bubble.left.and.text.bubble.right")
            .frame(maxWidth: .infinity)
            .padding(.top, MeetPRSpacing.xl)
        } else {
          ForEach(feedback) { item in
            FeedbackHistoryRow(item: item, exerciseName: exerciseName(for: item.planExerciseID))
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bgBase)
  }

  private func exerciseName(for id: UUID?) -> String? {
    guard let id else { return nil }
    return days.flatMap(\.exercises).first { $0.id == id }?.exercise.name
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackHistoryRow: View {
  let item: CoachFeedback
  let exerciseName: String?

  var body: some View {
    Card(accessibilityLabel: "反馈") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Text(item.text)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(4)

        HStack(spacing: MeetPRSpacing.sm) {
          if let dayDate = item.dayDate {
            chip(CoachStudentFormatting.shortDateText(dayDate), systemImage: "calendar")
          }
          if let exerciseName {
            chip(exerciseName, systemImage: "figure.strengthtraining.traditional")
          }
          Spacer(minLength: MeetPRSpacing.sm)
          Text(CoachStudentFormatting.relativeText(item.postedAt))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.textTertiary)
        }

        Text(item.readAt == nil ? "未读" : "已读")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(item.readAt == nil ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
      }
    }
  }

  private func chip(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .lineLimit(1)
      .padding(.horizontal, MeetPRSpacing.sm)
      .padding(.vertical, MeetPRSpacing.point5)
      .background(Color.MeetPR.surfaceElevated)
      .clipShape(.capsule)
  }
}
