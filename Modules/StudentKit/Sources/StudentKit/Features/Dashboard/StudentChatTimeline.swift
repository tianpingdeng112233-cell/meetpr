import ChatUI
import CoreModels
import DesignSystem
import Foundation

enum StudentChatTimelineItem: Identifiable, Sendable {
  case chat(ChatTimelineItem)
  case plan(DashboardPlanNotice)
  case feedback(CoachFeedback)

  var id: String {
    switch self {
    case .chat(let item):
      item.id
    case .plan(let notice):
      "plan-\(notice.signature.rawValue)"
    case .feedback(let feedback):
      "feedback-\(feedback.id.uuidString)"
    }
  }

  var occurredAt: Date {
    switch self {
    case .chat(let item):
      item.groupingDate
    case .plan(let notice):
      notice.occurredAt
    case .feedback(let feedback):
      feedback.postedAt
    }
  }
  var timestamp: Date {
    if case .chat(let item) = self { return item.timestamp }
    return occurredAt
  }

}

enum StudentChatTimeline {
  static let feedbackReadVisibilityThreshold = 0.55

  static func merged(
    messages: [ChatMessage],
    plan: DashboardPlanNotice?,
    feedback: [CoachFeedback]
  ) -> [StudentChatTimelineItem] {
    merged(chatItems: messages.map { .message($0) }, plan: plan, feedback: feedback)
  }

  static func merged(
    chatItems: [ChatTimelineItem], plan: DashboardPlanNotice?, feedback: [CoachFeedback]
  ) -> [StudentChatTimelineItem] {
    var items = chatItems.map(StudentChatTimelineItem.chat)
    if let plan {
      items.append(.plan(plan))
    }
    items.append(contentsOf: feedback.map(StudentChatTimelineItem.feedback))
    return items.sorted { lhs, rhs in
      if lhs.occurredAt == rhs.occurredAt {
        return lhs.id < rhs.id
      }
      return lhs.occurredAt < rhs.occurredAt
    }
  }

  static func visibleFraction(card: CGRect, viewport: CGRect) -> Double {
    guard card.height > 0 else { return 0 }
    let visibleHeight = max(
      0,
      min(card.maxY, viewport.maxY) - max(card.minY, viewport.minY)
    )
    return min(1, visibleHeight / card.height)
  }

  static func videoLabel(
    for video: CoachFeedbackVideo?,
    locale: Locale = .current
  ) -> String {
    guard let video else {
      return StudentStrings.localized(.studentChatTimeline001, locale: locale)
    }
    let exercise =
      StudentExerciseName.display(video, locale: locale)
      ?? StudentStrings.localized(.studentRootView002, locale: locale)
    // Mockup 643 fixed copy has no space after 我的: 我的深蹲 · 第 1 组.
    var parts = [
      StudentStrings.replacing(
        .studentChatTimeline002,
        values: ["\(exercise)"],
        locale: locale
      )
    ]
    if let setIndex = video.setIndex {
      parts.append(
        StudentStrings.replacing(
          .studentChatTimeline003,
          values: ["\(SetIndexDisplay.number(forZeroBasedIndex: setIndex))"],
          locale: locale
        ))
    }
    return parts.joined(separator: " · ")
  }

  @MainActor
  static func loadOlderPreservingPosition(
    in viewModel: ConversationViewModel,
    plan: DashboardPlanNotice?,
    feedback: [CoachFeedback]
  ) async -> String? {
    let anchor = merged(
      chatItems: viewModel.timelineItems,
      plan: plan,
      feedback: feedback
    ).first?.id
    await viewModel.loadOlder()
    return anchor
  }
}
