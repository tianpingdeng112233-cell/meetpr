import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
public struct ConversationView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: ConversationViewModel
  @State private var selectedImage: SelectedChatImage?
  @State private var selectedVideo: SelectedChatVideo?

  public init(
    conversationID: UUID,
    currentUserID: UUID,
    repository: any ChatRepository,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator
  ) {
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
    VStack(spacing: 0) {
      if viewModel.error != nil {
        ChatErrorBanner()
      }

      ConversationTimeline(
        viewModel: viewModel,
        selectedImage: $selectedImage,
        selectedVideo: $selectedVideo
      )

      Divider()
        .overlay(Color.MeetPR.border)
      ChatComposer(viewModel: viewModel)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle(ChatStrings.messages)
    .task(id: scenePhase) {
      guard scenePhase == .active else {
        return
      }
      await viewModel.load()
      await viewModel.refreshImagesIfNeeded()
      await viewModel.refreshVideosIfNeeded()
      await viewModel.pollUntilCancelled()
    }
    .modifier(
      ChatImagePresentationModifier(
        selectedImage: $selectedImage,
        viewModel: viewModel
      )
    )
    .modifier(
      ChatVideoPresentationModifier(
        selectedVideo: $selectedVideo,
        viewModel: viewModel
      )
    )
  }
}

private struct SelectedChatImage: Identifiable {
  let id: UUID
}

private struct SelectedChatVideo: Identifiable {
  let id: UUID
  let url: URL
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

@MainActor
private struct ChatVideoPresentationModifier: ViewModifier {
  @Binding var selectedVideo: SelectedChatVideo?
  let viewModel: ConversationViewModel

  func body(content: Content) -> some View {
    #if os(iOS)
      content
        .fullScreenCover(item: $selectedVideo, content: videoContent)
    #else
      content
        .sheet(item: $selectedVideo, content: videoContent)
    #endif
  }

  private func videoContent(_ selection: SelectedChatVideo) -> some View {
    FeedbackVideoPlayerView(
      videoID: selection.id,
      url: selection.url,
      refreshURL: { _ in
        try await viewModel.videoPlaybackURL(
          messageID: selection.id,
          forceRenewal: true
        )
      }
    )
  }
}

private struct ChatErrorBanner: View {
  var body: some View {
    Text(ChatStrings.sendFailed)
      .font(.footnote)
      .foregroundStyle(Color.MeetPR.brandRed)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.brandRedSoft)
  }
}

@MainActor
private struct ConversationTimeline: View {
  let viewModel: ConversationViewModel
  @Binding var selectedImage: SelectedChatImage?
  @Binding var selectedVideo: SelectedChatVideo?
  @State private var scrollPosition: String?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: MeetPRSpacing.sm) {
        if viewModel.hasMoreHistory {
          HistoryLoadingSentinel(load: loadOlderPreservingPosition)
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
            openVideo: {
              Task {
                guard
                  let url = try? await viewModel.videoPlaybackURL(messageID: message.id)
                else {
                  return
                }
                selectedVideo = SelectedChatVideo(id: message.id, url: url)
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
