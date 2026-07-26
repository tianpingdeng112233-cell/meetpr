import DesignSystem
import SwiftUI

/// A coach-side event surfaced *inside* the conversation stream, per the
/// mockup: plan publishes and feedback don't get their own notification hub,
/// they are messages.
public struct ConversationEventItem: Identifiable {
  public enum Kind {
    /// The bubble-shaped card with the gold 新计划 mini-pill.
    case planPublished
    /// The gold left-border feedback card.
    case feedback
  }

  public let id: String
  public let kind: Kind
  public let title: String
  public let subtitle: String
  public let isUnread: Bool
  public let action: @MainActor () -> Void

  public init(
    id: String,
    kind: Kind,
    title: String,
    subtitle: String,
    isUnread: Bool,
    action: @escaping @MainActor () -> Void
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.subtitle = subtitle
    self.isUnread = isUnread
    self.action = action
  }
}

/// Renders one event as an incoming-side stream card, matching the mockup's
/// two shapes exactly (16/16/16/5 bubble for plans, 5/16/16/5 gold-edge card
/// for feedback).
struct ConversationEventCard: View {
  let item: ConversationEventItem

  var body: some View {
    HStack {
      Button(action: item.action) {
        switch item.kind {
        case .planPublished: planCard
        case .feedback: feedbackCard
        }
      }
      .buttonStyle(PressScaleButtonStyle())
      Spacer(minLength: MeetPRSpacing.point28)
    }
  }

  private var planCard: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: "calendar.badge.clock")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: 40, height: 40)
        .background(Color.MeetPR.surfaceRaised)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text("新计划")
          .font(.MeetPR.mono(size: 9, weight: .bold))
          .tracking(0.9)
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(Color.MeetPR.goldSoft, in: .capsule)
        Text(item.title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(item.subtitle)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      Image(systemName: "chevron.right")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point13)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: MeetPRRadius.card, bottomLeading: MeetPRRadius.micro,
          bottomTrailing: MeetPRRadius.card, topTrailing: MeetPRRadius.card
        )
      )
      .stroke(Color.MeetPR.borderControl, lineWidth: 1)
    }
    .clipShape(
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: MeetPRRadius.card, bottomLeading: MeetPRRadius.micro,
          bottomTrailing: MeetPRRadius.card, topTrailing: MeetPRRadius.card
        )
      )
    )
    .accessibilityElement(children: .combine)
  }

  private var feedbackCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack(spacing: MeetPRSpacing.point6) {
        Circle().fill(Color.MeetPR.gold500).frame(width: 7, height: 7)
        Text("教练反馈")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer(minLength: MeetPRSpacing.space2)
        if item.isUnread {
          Text("未读")
            .font(.MeetPR.mono(size: 9, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(Color.MeetPR.inkOnGold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.MeetPR.gold500, in: .capsule)
        }
      }
      Text(item.title)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.bodyStrong)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
      Text(item.subtitle)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .padding(MeetPRSpacing.point13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .overlay(alignment: .leading) {
      Rectangle().fill(Color.MeetPR.gold500).frame(width: 3)
    }
    .clipShape(
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: MeetPRRadius.micro, bottomLeading: MeetPRRadius.micro,
          bottomTrailing: MeetPRRadius.card, topTrailing: MeetPRRadius.card
        )
      )
    )
    .accessibilityElement(children: .combine)
  }
}
