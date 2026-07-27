import ChatUI
import CoreModels
import Foundation

enum StudentChatTimelineItem: Identifiable, Equatable, Sendable {
  case message(ChatMessage)
  case plan(DashboardPlanNotice)
  case feedback(CoachFeedback)

  var id: String {
    switch self {
    case .message(let message):
      "message-\(message.id.uuidString)"
    case .plan(let notice):
      "plan-\(notice.signature.rawValue)"
    case .feedback(let feedback):
      "feedback-\(feedback.id.uuidString)"
    }
  }

  var occurredAt: Date {
    switch self {
    case .message(let message):
      message.createdAt
    case .plan(let notice):
      notice.occurredAt
    case .feedback(let feedback):
      feedback.postedAt
    }
  }
}

enum StudentChatTimeline {
  static let feedbackReadVisibilityThreshold = 0.55

  static func merged(
    messages: [ChatMessage],
    plan: DashboardPlanNotice?,
    feedback: [CoachFeedback]
  ) -> [StudentChatTimelineItem] {
    var items = messages.map(StudentChatTimelineItem.message)
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

  static func videoLabel(for video: CoachFeedbackVideo?) -> String {
    guard let video else { return "我的训练视频" }
    // Mockup 643 fixed copy has no space after 我的: 我的深蹲 · 第 1 组.
    var parts = ["我的\(video.exerciseName ?? "训练")"]
    if let setIndex = video.setIndex {
      parts.append("第 \(setIndex) 组")
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
      messages: viewModel.renderedMessages,
      plan: plan,
      feedback: feedback
    ).first?.id
    await viewModel.loadOlder()
    return anchor
  }
}
