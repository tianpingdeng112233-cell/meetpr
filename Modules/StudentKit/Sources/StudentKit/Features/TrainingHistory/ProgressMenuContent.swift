import DesignSystem
import SwiftUI

enum ProgressMenuDestination: CaseIterable, Hashable, Sendable {
  case e1rm
  case history
  case feedback
  case intensity

  var title: String {
    switch self {
    case .e1rm: StudentStrings.localized(.progressE1rm)
    case .history: StudentStrings.localized(.e1rmSourceHistory)
    case .feedback: StudentStrings.localized(.feedbackInboxView006)
    case .intensity: StudentStrings.localized(.progressIntensity)
    }
  }

  var icon: String {
    switch self {
    case .e1rm: "chart.line.uptrend.xyaxis"
    case .history: "clock"
    case .feedback: "bubble.left"
    case .intensity: "chart.bar"
    }
  }

  func value(from values: ProgressMenuValues?) -> String? {
    switch self {
    case .e1rm: values?.e1rm
    case .history: values?.history
    case .feedback: values?.feedback
    case .intensity: values?.intensity
    }
  }
}

struct ProgressMenuContent: View {
  let values: ProgressMenuValues?
  let isFailed: Bool
  let onOpen: (ProgressMenuDestination) -> Void
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      ForEach(ProgressMenuDestination.allCases, id: \.self) { destination in
        StudentMenuRow(
          icon: destination.icon, title: destination.title, value: destination.value(from: values),
          valueColor: destination == .feedback && values?.feedbackEmphasized == true
            ? .MeetPR.goldText : .MeetPR.textMuted,
          action: { onOpen(destination) })
      }
      if isFailed {
        ProgressRetryRow(onRetry: onRetry)
      }
    }
  }
}

struct ProgressRetryRow: View {
  let onRetry: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.localized(.trainingHistoryView022))
      Text("·")
      Button(StudentStrings.localized(.trainingHistoryView023), action: onRetry)
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
    .foregroundStyle(Color.MeetPR.textSecondary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
