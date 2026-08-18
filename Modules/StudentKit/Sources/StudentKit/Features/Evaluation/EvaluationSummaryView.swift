import CoreModels
import DesignSystem
import SwiftUI

/// Read-only full evaluation summary (spec 033 §12): the three sections plus
/// the update date. Appearing marks the summary read (local timestamp, D7).
@available(iOS 17.0, macOS 14.0, *)
public struct EvaluationSummaryView: View {
  private let summary: EvaluationSummary
  private let onRead: @MainActor () -> Void

  public init(summary: EvaluationSummary, onRead: @escaping @MainActor () -> Void = {}) {
    self.summary = summary
    self.onRead = onRead
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Text(
          StudentStrings.replacing(
            .evaluationSummaryView001,
            values: ["\(StudentFormatting.dayMonth(summary.lastUpdatedAt))"])
        )
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgTertiary)

        sectionCard(
          StudentStrings.localized(.evaluationSummaryView002), text: summary.overallAssessment)
        sectionCard(StudentStrings.localized(.evaluationSummaryView003), text: summary.trainingPlan)
        if let words = summary.wordsToStudent {
          sectionCard(StudentStrings.localized(.evaluationSummaryView004), text: words)
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle(StudentStrings.localized(.evaluationSummaryView005))
    .onAppear {
      onRead()
    }
  }

  private func sectionCard(_ title: String, text: String) -> some View {
    Card(accessibilityLabel: title) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow(title)
        Text(text)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
