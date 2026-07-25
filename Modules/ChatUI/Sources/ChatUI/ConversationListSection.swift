import CoreModels
import DesignSystem
import SwiftUI

@MainActor
public struct ConversationListSection: View {
  private let inbox: ChatInboxViewModel
  private let onSelect: @MainActor (ChatConversation) -> Void
  @State private var hasRefreshed = false

  public init(
    inbox: ChatInboxViewModel,
    onSelect: @escaping @MainActor (ChatConversation) -> Void
  ) {
    self.inbox = inbox
    self.onSelect = onSelect
  }

  public var body: some View {
    Group {
      if inbox.conversations.isEmpty {
        Text(ChatStrings.noConversations)
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(MeetPRSpacing.base)
      } else {
        LazyVStack(spacing: MeetPRSpacing.zero) {
          ForEach(inbox.conversations) { conversation in
            Button {
              onSelect(conversation)
            } label: {
              ConversationListRow(conversation: conversation)
            }
            .buttonStyle(PressScaleButtonStyle())

            if conversation.id != inbox.conversations.last?.id {
              Divider()
                .overlay(Color.MeetPR.borderDefault)
            }
          }
        }
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      }
    }
    .task {
      guard !hasRefreshed else {
        return
      }
      hasRefreshed = true
      await inbox.refresh()
    }
  }
}

private struct ConversationListRow: View {
  let conversation: ChatConversation

  var body: some View {
    HStack(spacing: MeetPRSpacing.md) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(conversation.otherPartyName)
            .font(.body.bold())
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineLimit(1)
          Spacer(minLength: MeetPRSpacing.sm)
          if let date = conversation.lastMessageAt {
            // Not `style: .relative` — that follows the device locale and renders
            // "7 min, 39 secs" inside an otherwise Chinese UI. The app ships
            // Chinese only, matching CoachKit's CoachStudentFormatting.
            Text(ChatRelativeTime.text(date))
              .font(.caption)
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
        }

        HStack(spacing: MeetPRSpacing.sm) {
          Text(preview)
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.textSecondary)
            .lineLimit(1)
          Spacer(minLength: MeetPRSpacing.sm)
          if conversation.unreadCount > 0 {
            Circle()
              .fill(MeetPRSemanticTone.unread.color)
              .frame(width: 8, height: 8)
              .accessibilityLabel("\(conversation.unreadCount) \(ChatStrings.unread)")
          }
        }
      }

      Image(systemName: "chevron.right")
        .font(.footnote.bold())
        .foregroundStyle(Color.MeetPR.textTertiary)
        .accessibilityHidden(true)
    }
    .padding(MeetPRSpacing.base)
    .contentShape(.rect)
  }

  private var preview: String {
    guard let preview = conversation.lastMessagePreview, !preview.isEmpty else {
      return ""
    }
    return preview == "[图片]" ? ChatStrings.image : preview
  }
}
