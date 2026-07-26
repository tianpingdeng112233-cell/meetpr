import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
public struct ConversationView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: ConversationViewModel
  @State private var selectedImage: SelectedChatImage?
  /// Coach-side events (plan publishes, feedback) rendered inside the stream
  /// — the design has no separate notification hub.
  private let events: [ConversationEventItem]

  public init(
    conversationID: UUID,
    currentUserID: UUID,
    repository: any ChatRepository,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator,
    events: [ConversationEventItem] = []
  ) {
    self.events = events
    _viewModel = State(
      initialValue: ConversationViewModel(
        conversationID: conversationID,
        currentUserID: currentUserID,
        repository: repository,
        sendCoordinator: sendCoordinator,
        inbox: inbox
      )
    )
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      if viewModel.error != nil {
        ChatErrorBanner()
      }

      ConversationTimeline(
        viewModel: viewModel,
        selectedImage: $selectedImage,
        events: events
      )

      Divider()
        .overlay(Color.MeetPR.borderDefault)
      ChatComposer(viewModel: viewModel)
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle(ChatStrings.messages)
    .task(id: scenePhase) {
      guard scenePhase == .active else {
        return
      }
      await viewModel.load()
      await viewModel.refreshImagesIfNeeded()
      await viewModel.pollUntilCancelled()
    }
    .modifier(
      ChatImagePresentationModifier(
        selectedImage: $selectedImage,
        viewModel: viewModel
      )
    )
  }
}

private struct SelectedChatImage: Identifiable {
  let id: UUID
}

@MainActor
private struct ChatImagePresentationModifier: ViewModifier {
  @Binding var selectedImage: SelectedChatImage?
  let viewModel: ConversationViewModel

  func body(content: Content) -> some View {
    #if os(iOS)
      content
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedImage, content: imageContent)
    #else
      content
        .sheet(item: $selectedImage, content: imageContent)
    #endif
  }

  private func imageContent(_ selection: SelectedChatImage) -> some View {
    ChatFullScreenImage(
      messageID: selection.id,
      viewModel: viewModel,
      dismiss: { selectedImage = nil }
    )
  }
}

private struct ChatErrorBanner: View {
  var body: some View {
    Text(ChatStrings.sendFailed)
      .font(.footnote)
      .foregroundStyle(Color.MeetPR.danger)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.dangerSoft)
  }
}

@MainActor
private struct ConversationTimeline: View {
  let viewModel: ConversationViewModel
  @Binding var selectedImage: SelectedChatImage?
  var events: [ConversationEventItem] = []
  @State private var scrollPosition: String?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: MeetPRSpacing.sm) {
        if viewModel.hasMoreHistory {
          HistoryLoadingSentinel(load: loadOlderPreservingPosition)
        }

        ForEach(events) { event in
          ConversationEventCard(item: event)
        }

        ForEach(viewModel.renderedMessages) { message in
          ChatMessageRow(
            message: message,
            isCurrentUser: message.senderID == viewModel.currentUserID,
            deliveryStatus: viewModel.deliveryStatus(for: message),
            openImage: {
              selectedImage = SelectedChatImage(id: message.id)
              Task {
                await viewModel.refreshImageIfNeeded(messageID: message.id)
              }
            },
            imageLoaded: {
              viewModel.imageLoaded(messageID: message.id)
            },
            imageFailed: {
              await viewModel.imageLoadingFailed(messageID: message.id)
            }
          )
          .id(messageScrollID(message.id))
        }

        ForEach(viewModel.pending, id: \.clientID) { item in
          PendingChatMessageRow(
            item: item,
            retry: { viewModel.retry(clientID: item.clientID) }
          )
          .id(pendingScrollID(item.clientID))
        }
      }
      .padding(MeetPRSpacing.base)
      .scrollTargetLayout()
    }
    .scrollIndicators(.hidden)
    .scrollPosition(id: $scrollPosition, anchor: .top)
    .defaultScrollAnchor(.bottom)
    .onChange(of: viewModel.renderedMessages.last?.id) { _, newID in
      if let newID {
        scrollPosition = messageScrollID(newID)
      }
    }
    .onChange(of: viewModel.pending.count) { _, _ in
      if let clientID = viewModel.pending.last?.clientID {
        scrollPosition = pendingScrollID(clientID)
      }
    }
  }

  private func loadOlderPreservingPosition() async {
    let anchor = viewModel.messages.first.map { messageScrollID($0.id) }
    await viewModel.loadOlder()
    if let anchor {
      scrollPosition = anchor
    }
  }

  private func messageScrollID(_ id: UUID) -> String {
    "message-\(id.uuidString)"
  }

  private func pendingScrollID(_ clientID: String) -> String {
    "pending-\(clientID)"
  }
}

private struct HistoryLoadingSentinel: View {
  let load: @MainActor () async -> Void

  var body: some View {
    ProgressView()
      .controlSize(.small)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.sm)
      .accessibilityLabel(ChatStrings.loadOlder)
      .task {
        await load()
      }
  }
}
