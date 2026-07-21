import CoreModels
import DesignSystem
import SwiftUI

struct ChatMessageRow: View {
  let message: ChatMessage
  let isCurrentUser: Bool
  let deliveryStatus: ChatDeliveryStatus?
  let openImage: @MainActor () -> Void
  let imageLoaded: @MainActor () -> Void
  let imageFailed: @MainActor () async -> Void

  var body: some View {
    HStack {
      if isCurrentUser {
        Spacer(minLength: MeetPRSpacing.xl)
      }

      VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: MeetPRSpacing.xs) {
        ChatMessageBubble(
          message: message,
          isCurrentUser: isCurrentUser,
          openImage: openImage,
          imageLoaded: imageLoaded,
          imageFailed: imageFailed
        )

        if let deliveryStatus {
          Text(deliveryStatus == .read ? ChatStrings.read : ChatStrings.delivered)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }

      if !isCurrentUser {
        Spacer(minLength: MeetPRSpacing.xl)
      }
    }
  }
}

private struct ChatMessageBubble: View {
  let message: ChatMessage
  let isCurrentUser: Bool
  let openImage: @MainActor () -> Void
  let imageLoaded: @MainActor () -> Void
  let imageFailed: @MainActor () async -> Void

  var body: some View {
    Group {
      switch message.kind {
      case .text:
        Text(message.text ?? "")
          .font(.body)
          .foregroundStyle(isCurrentUser ? .white : Color.MeetPR.fgPrimary)
          .padding(.horizontal, MeetPRSpacing.md)
          .padding(.vertical, MeetPRSpacing.sm)
      case .image:
        Button(action: openImage) {
          ChatRemoteImage(
            url: message.imageURL,
            imageLoaded: imageLoaded,
            imageFailed: imageFailed
          )
          .aspectRatio(4 / 3, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ChatStrings.image)
      }
    }
    .containerRelativeFrame(
      .horizontal,
      count: 4,
      span: 3,
      spacing: MeetPRSpacing.sm
    )
    .background(isCurrentUser ? Color.MeetPR.brandRed : Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.xl))
  }
}

private struct ChatRemoteImage: View {
  let url: URL?
  let imageLoaded: @MainActor () -> Void
  let imageFailed: @MainActor () async -> Void

  var body: some View {
    if let url {
      AsyncImage(url: url) { phase in
        switch phase {
        case .empty:
          ChatImagePlaceholder(showsProgress: true)
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
            .onAppear(perform: imageLoaded)
        case .failure:
          ChatImagePlaceholder(showsProgress: false)
            .task(id: url) {
              await imageFailed()
            }
        @unknown default:
          ChatImagePlaceholder(showsProgress: false)
        }
      }
    } else {
      ChatImagePlaceholder(showsProgress: false)
    }
  }
}

private struct ChatImagePlaceholder: View {
  let showsProgress: Bool

  var body: some View {
    ZStack {
      Color.MeetPR.surface2
      if showsProgress {
        ProgressView()
      } else {
        VStack(spacing: MeetPRSpacing.xs) {
          Image(systemName: "photo")
          Text(ChatStrings.imageUnavailable)
            .font(.caption)
        }
        .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }
}

struct PendingChatMessageRow: View {
  let item: ChatOutboxItem
  let retry: @MainActor () -> Void

  var body: some View {
    HStack {
      Spacer(minLength: MeetPRSpacing.xl)
      VStack(alignment: .trailing, spacing: MeetPRSpacing.xs) {
        Group {
          switch item.draft {
          case .text(let text):
            Text(text)
              .font(.body)
          case .image:
            Label(ChatStrings.image, systemImage: "photo")
              .font(.body)
          }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .containerRelativeFrame(
          .horizontal,
          count: 4,
          span: 3,
          spacing: MeetPRSpacing.sm
        )
        .background(Color.MeetPR.brandRed.opacity(0.72))
        .clipShape(.rect(cornerRadius: MeetPRRadius.xl))

        switch item.state {
        case .sending:
          Label(ChatStrings.sending, systemImage: "clock")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        case .failed:
          Button(action: retry) {
            Label(ChatStrings.retry, systemImage: "arrow.clockwise")
              .font(.caption.bold())
              .foregroundStyle(Color.MeetPR.brandRed)
          }
          .buttonStyle(.plain)
          .accessibilityHint(ChatStrings.sendFailed)
        case .confirmed:
          EmptyView()
        }
      }
    }
  }
}

@MainActor
struct ChatFullScreenImage: View {
  let messageID: UUID
  let viewModel: ConversationViewModel
  let dismiss: @MainActor () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black
        .ignoresSafeArea()

      if let message = viewModel.message(withID: messageID) {
        ChatRemoteImage(
          url: message.imageURL,
          imageLoaded: { viewModel.imageLoaded(messageID: messageID) },
          imageFailed: { await viewModel.imageLoadingFailed(messageID: messageID) }
        )
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ChatImagePlaceholder(showsProgress: false)
      }

      Button(action: dismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.title)
          .foregroundStyle(.white)
          .padding(MeetPRSpacing.base)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(ChatStrings.close)
    }
    .task {
      await viewModel.refreshImageIfNeeded(messageID: messageID)
    }
  }
}
