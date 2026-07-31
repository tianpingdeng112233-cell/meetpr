import Analytics
import ChatUI
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachReceivingView: View {
  private let now: Date
  private let videoQueueViewModel: CoachVideoQueueViewModel
  private let trainingLogs: any StudentTrainingLogRepository
  private let markerRepository: any VideoMarkerRepository
  private let studentStatuses: [UUID: CoachStudentStatus]
  private let chat: CoachChatContext?

  @State private var conversationOpener: CoachConversationOpener
  @State private var videoStudentTarget: PendingVideoStudentGroup?

  init(
    now: Date,
    videoQueueViewModel: CoachVideoQueueViewModel,
    trainingLogs: any StudentTrainingLogRepository = EmptyStudentTrainingLogRepository(),
    markerRepository: any VideoMarkerRepository = InMemoryVideoMarkerRepository(),
    studentStatuses: [UUID: CoachStudentStatus] = [:],
    chat: CoachChatContext? = nil
  ) {
    self.now = now
    self.videoQueueViewModel = videoQueueViewModel
    self.trainingLogs = trainingLogs
    self.markerRepository = markerRepository
    self.studentStatuses = studentStatuses
    self.chat = chat
    _conversationOpener = State(initialValue: CoachConversationOpener(chat: chat))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          header

          if rows.isEmpty {
            emptyState
          } else {
            conversationCard
            Text(CoachInboxStrings.hint)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textDisabled)
              .lineSpacing(MeetPRSpacing.point7)
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .refreshable {
        async let videoRefresh: Void = videoQueueViewModel.refresh()
        if let chat {
          async let chatRefresh: Void = chat.inbox.refresh()
          _ = await (videoRefresh, chatRefresh)
        } else {
          await videoRefresh
        }
      }
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(item: $videoStudentTarget) { group in
        StudentPendingVideosView(
          studentID: group.studentID,
          studentName: group.studentName,
          viewModel: videoQueueViewModel,
          trainingLogs: trainingLogs,
          markerRepository: markerRepository
        )
      }
      .navigationDestination(item: conversationDestinationBinding) { conversation in
        if let chat {
          CoachConversationDestination(
            conversationID: conversation.id,
            chat: chat,
            studentName: conversationOpener.destinationStudentName,
            studentStatus: studentStatuses[conversation.otherPartyID]
          )
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .alert(
      CoachStrings.unableToOpenConversation,
      isPresented: conversationErrorBinding
    ) {
      Button(CoachStrings.confirmation, role: .cancel) {
        conversationOpener.dismissError()
      }
    }
    .task {
      Analytics.shared.screen(.coachReceiving)
      await videoQueueViewModel.loadIfNeeded()
    }
  }

  private var rows: [CoachInboxRow] {
    CoachInboxPresentation.rows(
      conversations: chat?.inbox.conversations ?? [],
      videoGroups: videoQueueViewModel.studentGroups,
      now: now
    )
  }

  private var feedCount: Int {
    CoachInboxPresentation.count(
      conversations: chat?.inbox.conversations ?? [],
      pendingVideoCount: videoQueueViewModel.pendingCount
    )
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
      Text(CoachInboxStrings.eyebrow(feedCount))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
        .tracking(MeetPRFontMetrics.size11 * 0.06)
        .foregroundStyle(Color.MeetPR.gold500)
      Text(CoachInboxStrings.title)
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
  }

  private var conversationCard: some View {
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        if index > 0 {
          Rectangle()
            .fill(Color.MeetPR.borderHairline)
            .frame(height: MeetPRSpacing.point1)
        }
        inboxRow(row)
      }
    }
    .meetPRCardSurface(.card)
  }

  private func inboxRow(_ row: CoachInboxRow) -> some View {
    HStack(spacing: MeetPRSpacing.point11) {
      conversationButton(row)

      if row.hasUnread {
        Circle()
          .fill(Color.MeetPR.danger)
          .frame(width: MeetPRSpacing.space2, height: MeetPRSpacing.space2)
          .accessibilityLabel(CoachInboxStrings.unreadAccessibility(row.unreadCount))
      }

      if let videoGroup = row.videoGroup {
        pendingVideosButton(videoGroup, studentName: row.studentName)
      }

      Image(systemName: "chevron.right")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDisabled)
        .accessibilityHidden(true)
    }
    .padding(.leading, MeetPRSpacing.space4)
    .padding(.trailing, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.space3)
  }

  private func conversationButton(_ row: CoachInboxRow) -> some View {
    Button {
      openConversation(row)
    } label: {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(row.studentName)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
        Text(row.lastPreview)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("coach.inbox.chat.\(row.studentID.uuidString)")
  }

  private func pendingVideosButton(
    _ videoGroup: PendingVideoStudentGroup,
    studentName: String
  ) -> some View {
    Button {
      // Intentional prototype deviation: retain the per-student queue list
      // between the inbox rollup and the full-screen feedback workbench.
      videoStudentTarget = videoGroup
    } label: {
      HStack(spacing: MeetPRSpacing.point5) {
        Image(systemName: "play.fill")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
        Text(videoGroup.count.formatted())
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
      }
      .foregroundStyle(Color.MeetPR.inkOnCTAFill)
      .padding(.horizontal, MeetPRSpacing.point11)
      .padding(.vertical, MeetPRSpacing.point6)
      .background(Color.MeetPR.textPrimary)
      .clipShape(.capsule)
    }
    .buttonStyle(PressScaleButtonStyle(scale: 0.94))
    .accessibilityLabel(
      CoachInboxStrings.pendingVideosAccessibility(
        name: studentName,
        count: videoGroup.count
      )
    )
    .accessibilityIdentifier("coach.inbox.video.\(videoGroup.studentID.uuidString)")
  }

  private var emptyState: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      ZStack {
        Circle()
          .fill(Color.MeetPR.surfaceCard)
          .frame(width: MeetPRSpacing.point52, height: MeetPRSpacing.point52)
        Image(systemName: "bubble.left.and.bubble.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
          .foregroundStyle(Color.MeetPR.success)
      }
      Text(CoachInboxStrings.emptyTitle)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(CoachInboxStrings.emptySubtitle)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textDisabled)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.point32)
  }

  private func openConversation(_ row: CoachInboxRow) {
    if let conversation = row.conversation {
      conversationOpener.openConversation(
        conversation,
        studentName: row.studentName
      )
      return
    }
    Task {
      await conversationOpener.openConversation(
        withOtherParty: row.studentID,
        studentName: row.studentName
      )
    }
  }

}

extension CoachReceivingView {
  fileprivate var conversationDestinationBinding: Binding<ChatConversation?> {
    Binding(
      get: { conversationOpener.destination },
      set: { destination in
        if destination == nil {
          conversationOpener.dismissDestination()
        }
      }
    )
  }

  fileprivate var conversationErrorBinding: Binding<Bool> {
    Binding(
      get: { conversationOpener.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          conversationOpener.dismissError()
        }
      }
    )
  }
}
