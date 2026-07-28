import ChatUI
import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func newPlanNoticePersistsSeenState() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let seenStore = InMemoryDashboardPlanSeenStore()
  let plans = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )
  let viewModel = makeNotifications(plans: plans, seenStore: seenStore)

  await viewModel.loadIfNeeded(studentID: studentID)
  #expect(viewModel.planNotice?.weekIndex == plan.weekIndex)
  #expect(viewModel.totalUnreadCount == 1)

  viewModel.markCurrentPlanSeen()
  #expect(viewModel.planNotice == nil)
  #expect(viewModel.totalUnreadCount == 0)

  await viewModel.reload(studentID: studentID)
  #expect(viewModel.planNotice == nil)
}

@MainActor
// swiftlint:disable:next function_body_length
@Test func notificationBadgeAddsPlanFeedbackEvaluationAndChatUnread() async throws {
  let studentID = StudentDemoSeed.studentID
  let coachID = StudentDemoSeed.coachID
  let plan = StudentDemoSeed.makePlanView()
  let seenStore = InMemoryDashboardPlanSeenStore()
  let plans = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )
  let feedback = FeedbackInboxViewModel(
    repository: InMemoryStudentFeedbackRepository(
      seed: StudentDemoSeed.makeFeedback(studentID: studentID)
    )
  )
  let summary = EvaluationSummary(
    id: UUID(),
    studentId: studentID,
    coachId: coachID,
    overallAssessment: "状态稳定",
    trainingPlan: "继续训练",
    firstSavedAt: .distantPast,
    lastUpdatedAt: Date(),
    isActive: true
  )
  let evaluation = StudentEvaluationSummaryViewModel(
    summaries: InMemoryEvaluationSummaryRepository(seed: [summary]),
    plans: plans,
    readStore: InMemoryEvaluationSummaryReadStore()
  )
  let conversationID = UUID()
  let incomingMessages = (1...3).map { sequence in
    ChatMessage(
      id: UUID(),
      conversationID: conversationID,
      seq: sequence,
      senderID: coachID,
      kind: .text,
      text: "消息 \(sequence)",
      attachmentID: nil,
      imageURL: nil,
      imageExpiresIn: nil,
      clientID: "coach-message-\(sequence)",
      createdAt: Date().addingTimeInterval(Double(sequence))
    )
  }
  let conversation = ChatConversation(
    id: conversationID,
    otherPartyID: coachID,
    otherPartyName: "周教练",
    lastMessagePreview: "明天加重量",
    lastMessageAt: Date(),
    unreadCount: 3,
    myLastRead: nil,
    otherLastRead: nil
  )
  let chat = InMemoryChatRepository(
    currentUserID: studentID,
    seed: ChatDemoSeed(
      conversations: [conversation],
      messagesByConversationID: [conversationID: incomingMessages],
      otherPartyNames: [coachID: "周教练"]
    )
  )
  let inbox = ChatInboxViewModel(repository: chat, currentUserID: studentID)
  let coordinator = ChatSendCoordinator(repository: chat, currentUserID: studentID)
  let viewModel = StudentNotificationsCoordinator(
    plans: plans,
    feedback: feedback,
    evaluation: evaluation,
    activeCoach: ActiveCoachContext(coachID: coachID, coachDisplayName: "周教练"),
    chatContext: StudentChatContext(
      repository: chat,
      currentUserID: studentID,
      inbox: inbox,
      sendCoordinator: coordinator
    ),
    seenStore: seenStore
  )

  await viewModel.loadIfNeeded(studentID: studentID)

  #expect(viewModel.planNotice != nil)
  #expect(viewModel.feedbackUnreadCount == 2)
  #expect(viewModel.evaluationUnreadCount == 1)
  #expect(viewModel.chatUnreadCount == 3)
  #expect(viewModel.totalUnreadCount == 7)
}

@MainActor
@Test func fourBellConsumersShareOneCoordinatorLoad() async {
  let studentID = StudentDemoSeed.studentID
  let plans = CountingPlanRepository(plan: StudentDemoSeed.makePlanView())
  let coordinator = makeNotifications(plans: plans)

  for _ in StudentTab.allCases {
    await coordinator.loadIfNeeded(studentID: studentID)
  }

  let fetchCount = await plans.fetchCurrentPlanCount
  #expect(fetchCount == 2)
}

@MainActor
@Test func activeCoachRowOpensEmptyConversationEvenWithZeroUnread() async throws {
  let studentID = StudentDemoSeed.studentID
  let coachID = StudentDemoSeed.coachID
  let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore())
  let chat = InMemoryChatRepository(
    currentUserID: studentID,
    seed: ChatDemoSeed(
      conversations: [],
      messagesByConversationID: [:],
      otherPartyNames: [coachID: "周教练"]
    )
  )
  let inbox = ChatInboxViewModel(repository: chat, currentUserID: studentID)
  let coordinator = StudentNotificationsCoordinator(
    plans: plans,
    feedback: FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository()),
    evaluation: makeEvaluationViewModel(plans: plans),
    activeCoach: ActiveCoachContext(coachID: coachID, coachDisplayName: "周教练"),
    chatContext: StudentChatContext(
      repository: chat,
      currentUserID: studentID,
      inbox: inbox,
      sendCoordinator: ChatSendCoordinator(repository: chat, currentUserID: studentID)
    )
  )

  await coordinator.loadIfNeeded(studentID: studentID)
  #expect(coordinator.hasActiveCoach)
  #expect(coordinator.chatUnreadCount == 0)
  #expect(coordinator.coachConversation == nil)

  let openedConversationID = await coordinator.openCoachConversation()
  let openedID = try #require(openedConversationID)
  let conversations = try await chat.fetchConversations()
  #expect(conversations.count == 1)
  #expect(conversations.first?.id == openedID)
  #expect(conversations.first?.lastMessagePreview == nil)
}

@MainActor
@Test func lazyConversationCreationNetworkFailureReturnsNoRouteWithoutInvalidatingBind() async {
  let callback = BindingInvalidationRecorder()
  let coordinator = makeFailingChatNotifications(
    error: DashboardChatTestError.network,
    onBindingInvalidated: { await callback.record() }
  )

  let conversationID = await coordinator.openCoachConversation()

  #expect(conversationID == nil)
  #expect(!(await callback.hasRecordedCall))
}

@MainActor
@Test func bindRequiredDuringLazyConversationCreationInvalidatesBinding() async {
  let callback = BindingInvalidationRecorder()
  let coordinator = makeFailingChatNotifications(
    error: ChatRepositoryError.bindRequired,
    onBindingInvalidated: { await callback.record() }
  )

  let conversationID = await coordinator.openCoachConversation()

  #expect(conversationID == nil)
  #expect(await callback.invocationCount == 1)
}

@Test func userDefaultsPlanSeenStorePersistsPerStudentAndSignature() throws {
  let suiteName = "test.dashboard.plan-seen.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }

  let studentA = UUID()
  let studentB = UUID()
  let signature = DashboardPlanSignature(plan: StudentDemoSeed.makePlanView())
  let store = UserDefaultsDashboardPlanSeenStore(defaults: defaults)

  #expect(!store.hasSeen(studentID: studentA, signature: signature))
  store.markSeen(studentID: studentA, signature: signature)
  #expect(store.hasSeen(studentID: studentA, signature: signature))

  #expect(
    UserDefaultsDashboardPlanSeenStore(defaults: defaults)
      .hasSeen(studentID: studentA, signature: signature)
  )
  #expect(!store.hasSeen(studentID: studentB, signature: signature))
  let otherSignature = DashboardPlanSignature(plan: StudentDemoSeed.makePlanView(weekIndex: 2))
  #expect(!store.hasSeen(studentID: studentA, signature: otherSignature))
}

@MainActor
private func makeFailingChatNotifications(
  error: any Error & Sendable,
  onBindingInvalidated: @escaping @Sendable () async -> Void
) -> StudentNotificationsCoordinator {
  let studentID = StudentDemoSeed.studentID
  let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore())
  let chat = FailingOpenChatRepository(error: error)
  return StudentNotificationsCoordinator(
    plans: plans,
    feedback: FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository()),
    evaluation: makeEvaluationViewModel(plans: plans),
    activeCoach: ActiveCoachContext(
      coachID: StudentDemoSeed.coachID,
      coachDisplayName: "周教练"
    ),
    chatContext: StudentChatContext(
      repository: chat,
      currentUserID: studentID,
      inbox: ChatInboxViewModel(repository: chat, currentUserID: studentID),
      sendCoordinator: ChatSendCoordinator(repository: chat, currentUserID: studentID)
    ),
    onBindingInvalidated: onBindingInvalidated
  )
}

@MainActor
private func makeNotifications(
  plans: any StudentPlanRepository,
  seenStore: any DashboardPlanSeenStoring = InMemoryDashboardPlanSeenStore()
) -> StudentNotificationsCoordinator {
  StudentNotificationsCoordinator(
    plans: plans,
    feedback: FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository()),
    evaluation: makeEvaluationViewModel(plans: plans),
    activeCoach: nil,
    chatContext: nil,
    seenStore: seenStore
  )
}

@MainActor
private func makeEvaluationViewModel(
  plans: any StudentPlanRepository
) -> StudentEvaluationSummaryViewModel {
  StudentEvaluationSummaryViewModel(
    summaries: InMemoryEvaluationSummaryRepository(),
    plans: plans,
    readStore: InMemoryEvaluationSummaryReadStore()
  )
}

private enum DashboardChatTestError: Error, Sendable {
  case network
}

private actor BindingInvalidationRecorder {
  private(set) var invocationCount = 0

  var hasRecordedCall: Bool {
    invocationCount > 0
  }

  func record() {
    invocationCount += 1
  }
}

private actor FailingOpenChatRepository: ChatRepository {
  private let error: any Error & Sendable

  init(error: any Error & Sendable) {
    self.error = error
  }

  func fetchConversations() async throws -> [ChatConversation] {
    []
  }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    throw error
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
  }

  func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    throw error
  }

  func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    throw error
  }

  func sendSetRef(
    in conversationID: UUID,
    body: String,
    setRef: SetRefV1,
    videoID: UUID?,
    clientID: String
  ) async throws -> ChatMessage {
    throw error
  }

  func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    throw error
  }
}

private actor CountingPlanRepository: StudentPlanRepository {
  let plan: StudentPlanView?
  private(set) var fetchCurrentPlanCount = 0

  init(plan: StudentPlanView?) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    fetchCurrentPlanCount += 1
    return plan
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    nil
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    []
  }
}
