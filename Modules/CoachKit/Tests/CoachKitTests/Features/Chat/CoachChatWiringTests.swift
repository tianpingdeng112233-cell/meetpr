import ChatUI
import Foundation
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachShellRoutesDashboardAndRosterChatThroughMessagesTab() throws {
  let chat = makeChatContext()
  let context = try makeDetailContext(chat: chat)
  let rosterViewModel = StudentRosterViewModel(
    students: context.planning,
    plans: context.plans,
    trainingLogs: context.trainingLogs,
    feedback: context.feedback
  )
  let views = try [
    CoachDashboardView(
      context: context,
      now: Date(),
      chat: chat
    ).inspect().findAll(ChatEntryButton.self).count,
    StudentRosterView(
      viewModel: rosterViewModel,
      now: Date(),
      context: context,
      chat: chat
    ).inspect().findAll(ChatEntryButton.self).count,
    CoachPlanningHomeView(
      context: context,
      chat: chat
    ).inspect().findAll(ChatEntryButton.self).count,
    CoachReceivingView(
      now: Date(),
      videoQueueViewModel: CoachVideoQueueViewModel(
        repository: InMemoryCoachVideoQueueRepository()
      ),
      chat: chat
    ).inspect().findAll(ChatEntryButton.self).count,
    CoachMyProfileView(
      viewModel: CoachMyProfileViewModel(logoutAction: {}),
      inviteCodes: InMemoryInviteCodeRepository(),
      chat: chat
    ).inspect().findAll(ChatEntryButton.self).count,
  ]

  #expect(views == [0, 0, 1, 0, 1])
}

@Test func messageBadgeIncludesVideosAndChatUnread() {
  #expect(CoachMessageBadge.total(videos: 3, chatUnread: 4) == 7)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func directMessageEntryReopensTheSameConversation() async throws {
  let studentID = UUID()
  let userID = UUID()
  let seed = ChatDemoSeed(
    conversations: [],
    messagesByConversationID: [:],
    otherPartyNames: [studentID: "测试学员"]
  )
  let repository = InMemoryChatRepository(currentUserID: userID, seed: seed)
  let chat = CoachChatContext(
    repository: repository,
    currentUserID: userID,
    inbox: ChatInboxViewModel(repository: repository, currentUserID: userID),
    sendCoordinator: ChatSendCoordinator(repository: repository, currentUserID: userID)
  )
  let opener = CoachConversationOpener(chat: chat)

  await opener.openConversation(withOtherParty: studentID)
  let firstID = try #require(opener.destination?.id)
  opener.dismissDestination()
  await opener.openConversation(withOtherParty: studentID)

  #expect(opener.destination?.id == firstID)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func directMessageEntryCarriesStudentNameIntoEmptyConversation() async {
  let studentID = UUID()
  let userID = UUID()
  let repository = InMemoryChatRepository(
    currentUserID: userID,
    seed: ChatDemoSeed(
      conversations: [],
      messagesByConversationID: [:]
    )
  )
  let chat = CoachChatContext(
    repository: repository,
    currentUserID: userID,
    inbox: ChatInboxViewModel(repository: repository, currentUserID: userID),
    sendCoordinator: ChatSendCoordinator(repository: repository, currentUserID: userID)
  )
  let opener = CoachConversationOpener(chat: chat)

  await opener.openConversation(
    withOtherParty: studentID,
    studentName: "王晨曦"
  )

  #expect(opener.destinationStudentName == "王晨曦")
  #expect(opener.destination?.otherPartyID == studentID)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeChatContext() -> CoachChatContext {
  let userID = ChatDemoSeed.coachUserID
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .coach())
  return CoachChatContext(
    repository: repository,
    currentUserID: userID,
    inbox: ChatInboxViewModel(repository: repository, currentUserID: userID),
    sendCoordinator: ChatSendCoordinator(repository: repository, currentUserID: userID)
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeDetailContext(chat: CoachChatContext) throws -> CoachStudentDetailContext {
  CoachStudentDetailContext(
    plans: EmptyStudentPlanRepository(),
    trainingLogs: EmptyStudentTrainingLogRepository(),
    feedback: EmptyStudentFeedbackRepository(),
    evaluations: InMemoryCoachEvaluationRepository(),
    summaries: InMemoryCoachEvaluationSummaryRepository(coachId: chat.currentUserID),
    profiles: InMemoryCoachStudentProfileReader(),
    videos: InMemoryCoachStudentVideoRepository(),
    readiness: EmptyReadinessRepository(),
    familyMapProvider: nil,
    planning: InMemoryPlanRepository(students: [], catalog: []),
    draftStore: try DraftStore.inMemory(),
    chat: chat
  )
}
