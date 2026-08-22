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
  @State private var showsSetRefPicker = false
  private let setRefSharing: SetRefSharingContext?
  private let initialDraft: String
  private let conversationTitle: String
  private let conversationSubtitle: String?
  private let conversationSubtitleColor: Color
  private let outgoingBubbleColor: Color
  private let incomingBubbleColor: Color
  private let bubbleLayout: ChatBubbleLayout
  private let composerLayout: ChatComposerLayout

  public init(
    conversationID: UUID,
    currentUserID: UUID,
    repository: any ChatRepository,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator,
    setRefSharing: SetRefSharingContext? = nil,
    initialDraft: String = "",
    conversationTitle: String? = nil,
    conversationSubtitle: String? = nil,
    conversationSubtitleColor: Color = Color.MeetPR.textTertiary,
    outgoingBubbleColor: Color = Color.MeetPR.goldCTA,
    incomingBubbleColor: Color = Color.MeetPR.surfaceElevated,
    bubbleLayout: ChatBubbleLayout = .uniform,
    composerLayout: ChatComposerLayout = .standard
  ) {
    self.setRefSharing = setRefSharing
    self.initialDraft = initialDraft
    self.conversationTitle = conversationTitle ?? ChatStrings.messages
    self.conversationSubtitle = conversationSubtitle
    self.conversationSubtitleColor = conversationSubtitleColor
    self.outgoingBubbleColor = outgoingBubbleColor
    self.incomingBubbleColor = incomingBubbleColor
    self.bubbleLayout = bubbleLayout
    self.composerLayout = composerLayout
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
        selectedVideo: $selectedVideo,
        outgoingBubbleColor: outgoingBubbleColor,
        incomingBubbleColor: incomingBubbleColor,
        bubbleLayout: bubbleLayout
      )

      Divider()
        .overlay(Color.MeetPR.borderDefault)
      if setRefSharing == nil {
        ChatComposer(
          viewModel: viewModel,
          initialText: initialDraft,
          layout: composerLayout
        )
      } else {
        ChatComposer(
          viewModel: viewModel,
          initialText: initialDraft,
          layout: composerLayout,
          onShareTodayTraining: { showsSetRefPicker = true }
        )
      }
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle(conversationTitle)
    .modifier(
      ConversationHeaderModifier(
        title: conversationTitle,
        subtitle: conversationSubtitle,
        subtitleColor: conversationSubtitleColor
      )
    )
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
    .sheet(isPresented: $showsSetRefPicker) {
      if let setRefSharing {
        SetRefSharePicker(
          context: setRefSharing,
          conversationID: viewModel.conversationID,
          coordinator: viewModel.sendCoordinator,
          onStaged: { showsSetRefPicker = false }
        )
      }
    }
  }
}

public enum ChatBubbleLayout: Sendable {
  case uniform
  case directional
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
      .foregroundStyle(Color.MeetPR.goldCTA)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.goldSoft)
  }
}

private struct ConversationHeaderModifier: ViewModifier {
  let title: String
  let subtitle: String?
  let subtitleColor: Color

  func body(content: Content) -> some View {
    #if os(iOS)
      content.toolbar {
        if let subtitle {
          ToolbarItem(placement: .principal) {
            VStack(spacing: MeetPRSpacing.point2) {
              Text(title)
                .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
                .foregroundStyle(Color.MeetPR.textPrimary)
              Text(subtitle)
                .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
                .foregroundStyle(subtitleColor)
            }
          }
        }
      }
    #else
      content
    #endif
  }
}

@MainActor
private struct ConversationTimeline: View {
  let viewModel: ConversationViewModel
  @Binding var selectedImage: SelectedChatImage?
  @Binding var selectedVideo: SelectedChatVideo?
  let outgoingBubbleColor: Color
  let incomingBubbleColor: Color
  let bubbleLayout: ChatBubbleLayout
  @State private var scrollPosition: String?

  private var presentation: ConversationTimelinePresentation {
    ConversationTimelinePresentation.resolve(
      didFinishInitialLoad: viewModel.didFinishInitialLoad,
      hasLoadError: viewModel.error != nil,
      hasMessages: !viewModel.renderedMessages.isEmpty,
      hasPendingMessages: !viewModel.pending.isEmpty
    )
  }

  @ViewBuilder
  var body: some View {
    switch presentation {
    case .loading:
      ProgressView(ChatStrings.loadingMessages)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("chat.conversation.loading")
    case .failed:
      ContentUnavailableView(
        ChatStrings.loadMessagesFailed,
        systemImage: "exclamationmark.triangle"
      )
    case .empty:
      ContentUnavailableView(
        ChatStrings.noMessages,
        systemImage: "bubble.left.and.bubble.right",
        description: Text(ChatStrings.noMessagesDescription)
      )
      .accessibilityIdentifier("chat.conversation.empty")
    case .content:
      timeline
    }
  }

  private var timeline: some View {
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
            },
            outgoingBubbleColor: outgoingBubbleColor,
            incomingBubbleColor: incomingBubbleColor,
            bubbleLayout: bubbleLayout
          )
          .id(messageScrollID(message.id))
        }

        ForEach(viewModel.pending, id: \.clientID) { item in
          PendingChatMessageRow(
            item: item,
            retry: { viewModel.retry(clientID: item.clientID) },
            outgoingBubbleColor: outgoingBubbleColor,
            bubbleLayout: bubbleLayout
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
