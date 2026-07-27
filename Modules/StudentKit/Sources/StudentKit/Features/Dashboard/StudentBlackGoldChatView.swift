import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

// The four row implementations stay beside their student-only host so their
// mockup-line contracts cannot drift independently.
// swiftlint:disable file_length type_body_length

/// Student-only chat presentation. The coach continues to use ChatUI's
/// `ConversationView` unchanged.
///
/// Visual source of truth:
/// `docs/design/handoff-v3/MeetPR 学员端.dc.html`
/// helmet tokens at lines 10-44 and `showChat` at lines 630-650.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct StudentBlackGoldChatView: View {
  nonisolated private static let viewportCoordinateSpace =
    "student-black-gold-chat-viewport"

  let coachName: String
  let coordinator: StudentNotificationsCoordinator
  let onOpenTraining: @MainActor () -> Void
  let dismiss: @MainActor () -> Void

  @State private var viewModel: ConversationViewModel
  @State private var draft = ""
  @State private var scrollPosition: String?
  // Mockup 865 positions the target card's bottom near the viewport bottom;
  // history restoration (B4) needs a top anchor instead, so the anchor is
  // state that each assignment sets to match its own semantics.
  @State private var scrollAnchor: UnitPoint = .bottom
  @State private var viewportHeight: CGFloat = 0
  @State private var feedbackBeingMarkedRead: Set<UUID> = []
  @State private var didChooseInitialScrollPosition = false
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(
    conversationID: UUID,
    coachName: String,
    coordinator: StudentNotificationsCoordinator,
    currentUserID: UUID,
    repository: any ChatRepository,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator,
    onOpenTraining: @escaping @MainActor () -> Void,
    dismiss: @escaping @MainActor () -> Void
  ) {
    self.coachName = coachName
    self.coordinator = coordinator
    self.onOpenTraining = onOpenTraining
    self.dismiss = dismiss
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

  var body: some View {
    VStack(spacing: 0) {
      chatHeader
      timeline
      composer
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .background(Color.MeetPR.bgBase)
    .transaction { transaction in
      if reduceMotion {
        transaction.animation = nil
      }
    }
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      await viewModel.load()
      chooseInitialScrollPositionIfNeeded()
      await viewModel.pollUntilCancelled()
    }
    .onChange(of: viewModel.renderedMessages.last?.id) { _, messageID in
      guard didChooseInitialScrollPosition, let messageID else { return }
      scrollAnchor = .bottom
      scrollPosition = "message-\(messageID.uuidString)"
    }
    .onChange(of: viewModel.pending.count) { _, _ in
      guard let clientID = viewModel.pending.last?.clientID else { return }
      scrollAnchor = .bottom
      scrollPosition = "pending-\(clientID)"
    }
  }

  /// Mockup lines 633-636: 40pt circular back control, coach name, success
  /// presence text, and a hairline divider.
  private var chatHeader: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Button(action: dismiss) {
        Image(systemName: "chevron.left")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
          .background(Color.MeetPR.surfaceCard, in: .circle)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("返回")

      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(coachName)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        Text("● 在线")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.success)
      }

      Spacer()
    }
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.top, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.point14)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
  }

  /// Mockup lines 637-645: one chronological scroll merging chat, plan, and
  /// feedback items with 18pt insets and a 10pt row gap.
  private var timeline: some View {
    ScrollView {
      LazyVStack(spacing: MeetPRSpacing.point10) {
        if viewModel.hasMoreHistory {
          StudentChatHistoryLoadingSentinel(load: loadOlderPreservingPosition)
        }

        if let timestamp = timelineItems.first?.occurredAt {
          Text(chatTimestamp(timestamp))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textDim)
            .frame(maxWidth: .infinity)
            .padding(.bottom, MeetPRSpacing.space1)
        }

        ForEach(timelineItems) { item in
          timelineRow(item)
            .id(item.id)
        }

        ForEach(viewModel.pending, id: \.clientID) { pending in
          StudentPendingMessageRow(
            item: pending,
            retry: { viewModel.retry(clientID: pending.clientID) }
          )
          .id("pending-\(pending.clientID)")
        }
      }
      .padding(MeetPRSpacing.point18)
      .scrollTargetLayout()
    }
    .coordinateSpace(name: Self.viewportCoordinateSpace)
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.height
    } action: { height in
      viewportHeight = height
    }
    .scrollIndicators(.hidden)
    .scrollPosition(id: $scrollPosition, anchor: scrollAnchor)
    .defaultScrollAnchor(.bottom)
  }

  @ViewBuilder
  private func timelineRow(_ item: StudentChatTimelineItem) -> some View {
    switch item {
    case .message(let message):
      StudentChatMessageRow(
        message: message,
        isCurrentUser: message.senderID == viewModel.currentUserID,
        deliveryStatus: viewModel.deliveryStatus(for: message)
      )
    case .plan(let notice):
      StudentPlanChatCard(notice: notice, action: openTraining)
    case .feedback(let feedback):
      StudentFeedbackChatCard(feedback: feedback)
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .named(Self.viewportCoordinateSpace))
        } action: { frame in
          markFeedbackReadIfVisible(feedback, frame: frame)
        }
    }
  }

  /// Mockup lines 646-648: a 20pt input capsule containing the 34pt circular
  /// upward-arrow send control. Sending stays on spec 058's coordinator path.
  private var composer: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      HStack(spacing: MeetPRSpacing.space2) {
        TextField("输入消息", text: $draft, axis: .vertical)
          .lineLimit(1...5)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .textFieldStyle(.plain)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.vertical, MeetPRSpacing.point11)
          .onChange(of: draft) { _, value in
            if value.count > ConversationViewModel.maximumTextLength {
              draft = String(value.prefix(ConversationViewModel.maximumTextLength))
            }
          }

        Button(action: send) {
          Image(systemName: "arrow.up")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .semibold))
            .foregroundStyle(Color.MeetPR.ctaTopHighlight)
            .frame(width: MeetPRSpacing.point34, height: MeetPRSpacing.point34)
            .background(Color.MeetPR.borderStrong, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.55)
        .accessibilityLabel("发送")
      }
      .padding(.leading, MeetPRSpacing.space4)
      .padding(.trailing, MeetPRSpacing.point6)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: 20))
      .overlay {
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.space3)
    .padding(.bottom, MeetPRSpacing.point14)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
  }

  private var timelineItems: [StudentChatTimelineItem] {
    StudentChatTimeline.merged(
      messages: viewModel.renderedMessages,
      plan: coordinator.planNotice,
      feedback: coordinator.feedbackItems
    )
  }

  private var canSend: Bool {
    !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && draft.count <= ConversationViewModel.maximumTextLength
  }

  private func send() {
    guard viewModel.sendText(draft) != nil else { return }
    draft = ""
  }

  private func openTraining() {
    coordinator.markCurrentPlanSeen()
    dismiss()
    Task { @MainActor in
      await Task.yield()
      onOpenTraining()
    }
  }

  private func chooseInitialScrollPositionIfNeeded() {
    guard !didChooseInitialScrollPosition else { return }
    didChooseInitialScrollPosition = true
    let firstUnreadFeedback = timelineItems.first { item in
      if case .feedback(let feedback) = item {
        return feedback.readAt == nil
      }
      return false
    }
    // Mockup 865: the first unread card lands with its bottom near the
    // viewport bottom (the timeline's bottom padding supplies the 16pt gap).
    scrollAnchor = .bottom
    scrollPosition = firstUnreadFeedback?.id ?? timelineItems.last?.id
  }

  private func loadOlderPreservingPosition() async {
    let anchor = await StudentChatTimeline.loadOlderPreservingPosition(
      in: viewModel,
      plan: coordinator.planNotice,
      feedback: coordinator.feedbackItems
    )
    if let anchor {
      scrollAnchor = .top
      scrollPosition = anchor
    }
  }

  /// Mirrors mockup `checkVisible` at lines 865-867: only feedback cards with
  /// at least 55% of their own height inside `chatScroll` become read.
  private func markFeedbackReadIfVisible(_ feedback: CoachFeedback, frame: CGRect) {
    guard feedback.readAt == nil,
      !feedbackBeingMarkedRead.contains(feedback.id),
      viewportHeight > 0
    else { return }
    let viewport = CGRect(x: 0, y: 0, width: frame.width, height: viewportHeight)
    guard
      StudentChatTimeline.visibleFraction(card: frame, viewport: viewport)
        >= StudentChatTimeline.feedbackReadVisibilityThreshold
    else { return }

    feedbackBeingMarkedRead.insert(feedback.id)
    Task {
      await coordinator.markFeedbackRead(feedback)
      feedbackBeingMarkedRead.remove(feedback.id)
    }
  }

  private func chatTimestamp(_ date: Date) -> String {
    let time = date.formatted(
      .dateTime.hour().minute().locale(Locale(identifier: "zh_CN"))
    )
    if Calendar.current.isDateInToday(date) {
      return "今天 \(time)"
    }
    let day = date.formatted(
      .dateTime.month().day().locale(Locale(identifier: "zh_CN"))
    )
    return "\(day) \(time)"
  }
}

/// Mockup lines 640-641: asymmetric 16/16/16/5 and 16/16/5/16 bubbles.
private struct StudentChatMessageRow: View {
  let message: ChatMessage
  let isCurrentUser: Bool
  let deliveryStatus: ChatDeliveryStatus?

  var body: some View {
    HStack {
      if isCurrentUser {
        Spacer(minLength: 0)
      }

      VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: MeetPRSpacing.space1) {
        messageContent
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(
            isCurrentUser ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary
          )
          .lineSpacing(MeetPRFontMetrics.size14 * 0.45)
          .padding(.horizontal, MeetPRSpacing.point14)
          .padding(.vertical, MeetPRSpacing.point11)
          .background(
            isCurrentUser
              ? Color.MeetPR.textPrimary
              : Color.MeetPR.surfaceElevated
          )
          .clipShape(messageShape)

        if let deliveryStatus {
          Text(deliveryStatus == .read ? "已读" : "已送达")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textDim)
        }
      }

      if !isCurrentUser {
        Spacer(minLength: 0)
      }
    }
    .containerRelativeFrame(.horizontal) { length, _ in
      length * 0.76
    }
    .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
  }

  @ViewBuilder
  private var messageContent: some View {
    if message.kind == .image {
      Label("图片", systemImage: "photo")
    } else {
      Text(message.text ?? "")
        .fontWeight(isCurrentUser ? .medium : .regular)
    }
  }

  private var messageShape: UnevenRoundedRectangle {
    if isCurrentUser {
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: 16,
          bottomLeading: 16,
          bottomTrailing: 5,
          topTrailing: 16
        )
      )
    } else {
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: 16,
          bottomLeading: 5,
          bottomTrailing: 16,
          topTrailing: 16
        )
      )
    }
  }
}

/// Mockup line 642: 40pt calendar tile, gold monospaced badge, title,
/// subtitle, and trailing chevron.
private struct StudentPlanChatCard: View {
  let notice: DashboardPlanNotice
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: "calendar")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .medium))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
          .background(Color.MeetPR.surfaceRaised)
          .clipShape(.rect(cornerRadius: MeetPRRadius.control))

        VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
          Text("新计划")
            .font(.MeetPR.mono(size: 9, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(Color.MeetPR.goldText)
            .padding(.horizontal, MeetPRSpacing.point7)
            .padding(.vertical, MeetPRSpacing.point2)
            .background(Color.MeetPR.chatPlanBadgeFill, in: .capsule)
          Text("教练发布了新计划")
            .font(.MeetPR.body(size: 14.5, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.top, MeetPRSpacing.point3)
          Text("第 \(notice.weekIndex) 周计划已可查看 · 点按进入训练")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .medium))
          .foregroundStyle(Color.MeetPR.textDim)
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.point13)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(
        UnevenRoundedRectangle(
          cornerRadii: .init(
            topLeading: 16,
            bottomLeading: 5,
            bottomTrailing: 16,
            topTrailing: 16
          )
        )
      )
      .overlay {
        UnevenRoundedRectangle(
          cornerRadii: .init(
            topLeading: 16,
            bottomLeading: 5,
            bottomTrailing: 16,
            topTrailing: 16
          )
        )
        .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .containerRelativeFrame(.horizontal) { length, _ in
      length * 0.88
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Mockup line 643: 3pt gold rail, 5/16/16/5 corners, read state, and a
/// 150pt video cover with label, play control, and duration.
private struct StudentFeedbackChatCard: View {
  let feedback: CoachFeedback

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point9) {
      HStack(spacing: MeetPRSpacing.point7) {
        Circle()
          .fill(Color.MeetPR.gold500)
          .frame(width: MeetPRSpacing.point7, height: MeetPRSpacing.point7)
        Text("教练反馈")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        Spacer()
        readBadge
      }

      if feedback.videoID != nil {
        videoCover
      }

      Text(feedback.text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineSpacing(MeetPRFontMetrics.size14 * 0.5)
    }
    .padding(.horizontal, MeetPRSpacing.point13)
    .padding(.vertical, MeetPRSpacing.space3)
    .background {
      ZStack(alignment: .leading) {
        Color.MeetPR.surfaceCard
        Rectangle()
          .fill(Color.MeetPR.gold500)
          .frame(width: MeetPRSpacing.point3)
      }
    }
    .clipShape(
      UnevenRoundedRectangle(
        cornerRadii: .init(
          topLeading: 5,
          bottomLeading: 5,
          bottomTrailing: 16,
          topTrailing: 16
        )
      )
    )
    .containerRelativeFrame(.horizontal) { length, _ in
      length * 0.88
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var readBadge: some View {
    if feedback.readAt == nil {
      Text("未读")
        .font(.MeetPR.mono(size: 9, weight: .bold))
        .tracking(0.72)
        .foregroundStyle(Color.MeetPR.inkOnGold)
        .padding(.horizontal, MeetPRSpacing.point6)
        .padding(.vertical, MeetPRSpacing.point2)
        .background(Color.MeetPR.goldText, in: .capsule)
    } else {
      Label("已读", systemImage: "checkmark")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.goldText)
    }
  }

  private var videoCover: some View {
    ZStack {
      LinearGradient(
        colors: [Color.MeetPR.borderStrong, Color.MeetPR.surfaceCard],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Image(systemName: "play.fill")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .medium))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(.black.opacity(0.45), in: .circle)
        .overlay {
          Circle().stroke(.white.opacity(0.75), lineWidth: 1.5)
        }

      Text(videoLabel)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .padding(.horizontal, MeetPRSpacing.point7)
        .padding(.vertical, MeetPRSpacing.point2)
        .background(.black.opacity(0.5))
        .clipShape(.rect(cornerRadius: 5))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, MeetPRSpacing.space2)
        .padding(.leading, MeetPRSpacing.point9)

      Text(videoDuration)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
        .foregroundStyle(.white)
        .padding(.horizontal, MeetPRSpacing.point6)
        .padding(.vertical, MeetPRSpacing.point2)
        .background(.black.opacity(0.6))
        .clipShape(.rect(cornerRadius: 5))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.bottom, MeetPRSpacing.space2)
        .padding(.trailing, MeetPRSpacing.point9)
    }
    .frame(height: 150)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }

  private var videoLabel: String {
    StudentChatTimeline.videoLabel(for: feedback.video)
  }

  private var videoDuration: String {
    guard let duration = feedback.video?.durationSeconds else { return "—:—" }
    let minutes = duration / 60
    let seconds = duration % 60
    return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
  }
}

private struct StudentChatHistoryLoadingSentinel: View {
  let load: @MainActor () async -> Void

  var body: some View {
    ProgressView()
      .controlSize(.small)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.space2)
      .accessibilityLabel("加载更早消息")
      .task {
        await load()
      }
  }
}

private struct StudentPendingMessageRow: View {
  let item: ChatOutboxItem
  let retry: @MainActor () -> Void

  var body: some View {
    HStack {
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: MeetPRSpacing.space1) {
        pendingContent
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .medium))
          .foregroundStyle(Color.MeetPR.bgBase)
          .padding(.horizontal, MeetPRSpacing.point14)
          .padding(.vertical, MeetPRSpacing.point11)
          .background(Color.MeetPR.textPrimary.opacity(0.72))
          .clipShape(
            UnevenRoundedRectangle(
              cornerRadii: .init(
                topLeading: 16,
                bottomLeading: 16,
                bottomTrailing: 5,
                topTrailing: 16
              )
            )
          )

        switch item.state {
        case .sending:
          Label("发送中", systemImage: "clock")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textDim)
        case .failed:
          Button(action: retry) {
            Label("重试", systemImage: "arrow.clockwise")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
              .foregroundStyle(Color.MeetPR.danger)
          }
          .buttonStyle(.plain)
        case .confirmed:
          EmptyView()
        }
      }
    }
    .containerRelativeFrame(.horizontal) { length, _ in
      length * 0.76
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  @ViewBuilder
  private var pendingContent: some View {
    switch item.draft {
    case .text(let text):
      Text(text)
    case .image:
      Label("图片", systemImage: "photo")
    }
  }
}

// swiftlint:enable file_length type_body_length
