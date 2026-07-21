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
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(MeetPRSpacing.base)
      } else {
        LazyVStack(spacing: 0) {
          ForEach(inbox.conversations) { conversation in
            Button {
              onSelect(conversation)
            } label: {
              ConversationListRow(conversation: conversation)
            }
            .buttonStyle(.plain)

            if conversation.id != inbox.conversations.last?.id {
              Divider()
                .overlay(Color.MeetPR.border)
            }
          }
        }
        .background(Color.MeetPR.surface1)
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
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(1)
          Spacer(minLength: MeetPRSpacing.sm)
          if let date = conversation.lastMessageAt {
            Text(date, style: .relative)
              .font(.caption)
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }
        }

        HStack(spacing: MeetPRSpacing.sm) {
          Text(preview)
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)
          Spacer(minLength: MeetPRSpacing.sm)
          if conversation.unreadCount > 0 {
            Circle()
              .fill(Color.MeetPR.brandRed)
              .frame(width: 8, height: 8)
              .accessibilityLabel("\(conversation.unreadCount) \(ChatStrings.unread)")
          }
        }
      }

      Image(systemName: "chevron.right")
        .font(.footnote.bold())
        .foregroundStyle(Color.MeetPR.fgTertiary)
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
