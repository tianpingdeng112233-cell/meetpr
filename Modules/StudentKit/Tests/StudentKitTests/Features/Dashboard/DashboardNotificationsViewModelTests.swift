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
  #expect(viewModel.planNotice?.occurredAt == plan.startDate)
  #expect(viewModel.totalUnreadCount == 1)

  viewModel.markCurrentPlanSeen()
  #expect(viewModel.planNotice == nil)
  #expect(viewModel.totalUnreadCount == 0)

  await viewModel.reload(studentID: studentID)
  #expect(viewModel.planNotice == nil)
}

@MainActor
// swiftlint:disable:next function_body_length
@Test func notificationBadgeExcludesSealedEvaluationUnread() async throws {
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
  #expect(viewModel.totalUnreadCount == 6)
}

@MainActor
@Test func visibleFeedbackMarkReadSynchronizesCoordinatorAndArchiveUnreadState() async throws {
  let studentID = StudentDemoSeed.studentID
  let feedbackItem = CoachFeedback(
    id: UUID(),
    coachID: StudentDemoSeed.coachID,
    studentID: studentID,
    text: "保持起杠路径",
    postedAt: Date(),
    readAt: nil
  )
  let repository = InMemoryStudentFeedbackRepository(
    seed: [feedbackItem],
    now: { Date(timeIntervalSince1970: 1_900_000_000) }
  )
  let feedback = FeedbackInboxViewModel(repository: repository)
  let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore())
  let coordinator = StudentNotificationsCoordinator(
    plans: plans,
    feedback: feedback,
    evaluation: makeEvaluationViewModel(plans: plans),
    activeCoach: nil,
    chatContext: nil,
    seenStore: InMemoryDashboardPlanSeenStore()
  )

  await coordinator.loadIfNeeded(studentID: studentID)
  #expect(coordinator.feedbackUnreadCount == 1)
  #expect(feedback.unreadCount == 1)

  let visibleFraction = StudentChatTimeline.visibleFraction(
    card: CGRect(x: 0, y: 145, width: 300, height: 100),
    viewport: CGRect(x: 0, y: 0, width: 300, height: 200)
  )
  #expect(visibleFraction >= StudentChatTimeline.feedbackReadVisibilityThreshold)
  if visibleFraction >= StudentChatTimeline.feedbackReadVisibilityThreshold {
    await coordinator.markFeedbackRead(try #require(feedback.items.first))
  }

  #expect(coordinator.feedbackUnreadCount == 0)
  #expect(feedback.unreadCount == 0)
  #expect(feedback.items.first?.readAt != nil)
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
  #expect(coordinator.chatUnreadCount == 0)
  #expect(coordinator.coachConversation == nil)

  let openedConversationID = await coordinator.openCoachConversation()
  let openedID = try #require(openedConversationID)
  let conversations = try await chat.fetchConversations()
  #expect(conversations.count == 1)
  #expect(conversations.first?.id == openedID)
  #expect(conversations.first?.lastMessagePreview == nil)
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
