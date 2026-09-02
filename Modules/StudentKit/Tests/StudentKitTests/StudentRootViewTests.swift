import ChatUI
import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentRootViewInitializes() {
  _ = StudentRootView()
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentRootViewInitializesWithInjectedRepositories() {
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
  _ = StudentRootView(
    studentID: StudentDemoSeed.studentID,
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    feedback: InMemoryStudentFeedbackRepository()
  )
}

@MainActor
@Test func selfTrainRoleGateBuildsNoChatCoordinatorAndMakesZeroRequests() async {
  let chat = ChatRequestCountingRepository()
  let inbox = ChatInboxViewModel(repository: chat, currentUserID: StudentDemoSeed.studentID)
  let root = StudentRootView(
    studentID: StudentDemoSeed.studentID,
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository(),
    feedback: InMemoryStudentFeedbackRepository(),
    allowsChat: false,
    chat: chat,
    currentUserID: StudentDemoSeed.studentID,
    inbox: inbox,
    sendCoordinator: ChatSendCoordinator(
      repository: chat,
      currentUserID: StudentDemoSeed.studentID
    ),
    activeCoach: ActiveCoachContext(
      coachID: StudentDemoSeed.coachID,
      coachDisplayName: "不应显示"
    )
  )

  #expect(!root.hasNotificationCoordinator)
  #expect(await chat.requestCount == 0)
}

@MainActor
@Test func coachedRoleGateBuildsSharedNotificationCoordinator() {
  let chat = ChatRequestCountingRepository()
  let inbox = ChatInboxViewModel(repository: chat, currentUserID: StudentDemoSeed.studentID)
  let root = StudentRootView(
    studentID: StudentDemoSeed.studentID,
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository(),
    feedback: InMemoryStudentFeedbackRepository(),
    allowsChat: true,
    chat: chat,
    currentUserID: StudentDemoSeed.studentID,
    inbox: inbox,
    sendCoordinator: ChatSendCoordinator(
      repository: chat,
      currentUserID: StudentDemoSeed.studentID
    ),
    activeCoach: ActiveCoachContext(
      coachID: StudentDemoSeed.coachID,
      coachDisplayName: "周教练"
    )
  )

  #expect(root.hasNotificationCoordinator)
}

@Test func notificationRoutesAreIdenticalFromEveryTab() {
  for source in StudentTab.allCases {
    #expect(StudentNotificationRoute.plan.targetTab(from: source) == .training)
  }
}

@Test func planChangePushIntentsMapToTheStudentPlanRoute() {
  let studentID = UUID()
  let planID = UUID()

  #expect(
    StudentNotificationRoute.route(
      for: .planUpdated(studentID: studentID, planID: planID)
    ) == .plan
  )
  #expect(
    StudentNotificationRoute.route(
      for: .planPublished(studentID: studentID, planID: planID)
    ) == .plan
  )
}

@Test func tabLayersRemainMountedAcrossSelectionRoundTrip() {
  let training = StudentTabShellPresentation(selection: .training)
  let growth = StudentTabShellPresentation(selection: .growth)
  let returned = StudentTabShellPresentation(selection: .training)

  #expect(training.layers.map(\.id) == StudentTab.allCases)
  #expect(growth.layers.map(\.id) == StudentTab.allCases)
  #expect(returned.layers.map(\.id) == StudentTab.allCases)
  #expect(training.layer(for: .training) == returned.layer(for: .training))
  #expect(!growth.layer(for: .training).allowsHitTesting)
  #expect(growth.layer(for: .training).opacity == 0)
  #expect(growth.layer(for: .training).isAccessibilityHidden)
  #expect(!growth.layer(for: .training).isEnabled)
  #expect(returned.layer(for: .training).allowsHitTesting)
  #expect(!returned.layer(for: .training).isAccessibilityHidden)
  #expect(returned.layer(for: .training).isEnabled)
  #expect(returned.layer(for: .training).zIndex == 1)
}

@Test func exactlyOneTabLayerParticipatesInAccessibility() {
  for selection in StudentTab.allCases {
    let layers = StudentTabShellPresentation(selection: selection).layers
    let exposed = layers.filter { !$0.isAccessibilityHidden }

    #expect(exposed.map(\.id) == [selection])
    #expect(layers.filter(\.isEnabled).map(\.id) == [selection])
  }
}

@Test func trainingRefreshTriggerAcceptsActiveSceneAndTrainingTabOnly() {
  var trigger = StudentTrainingPlanRefreshTrigger()

  trigger.handleScenePhase(.background)
  trigger.handleTabSelection(.growth)
  #expect(trigger.revision == 0)

  trigger.handleScenePhase(.active)
  #expect(trigger.revision == 1)

  trigger.handleTabSelection(.training)
  #expect(trigger.revision == 2)
}

@Test func feedbackHeightReversalStartsFromCurrentPresentation() {
  #expect(
    FeedbackHeightTransition.resolvedStartHeight(
      presentedHeight: 184,
      fallbackHeight: 320
    ) == 184
  )
  #expect(
    FeedbackHeightTransition.resolvedStartHeight(
      presentedHeight: 0,
      fallbackHeight: 112
    ) == 112
  )
}

@Test func importedHistoryReviewQueueDeduplicatesAndAdvancesInOrder() {
  let current = pendingReview(family: .squat)
  let waiting = pendingReview(family: .bench)
  let incoming = pendingReview(family: .deadlift)

  let merged = ImportedHistoryReviewQueue.appendingUnique(
    [current, waiting, incoming, incoming],
    current: current,
    waiting: [waiting]
  )
  #expect(merged.map(\.id) == [waiting.id, incoming.id])

  let first = ImportedHistoryReviewQueue.takingNext(from: merged)
  #expect(first.current?.id == waiting.id)
  #expect(first.waiting.map(\.id) == [incoming.id])

  let second = ImportedHistoryReviewQueue.takingNext(from: first.waiting)
  #expect(second.current?.id == incoming.id)
  #expect(second.waiting.isEmpty)
}

private func pendingReview(family: LiftFamily) -> PendingImportedHistoryReview {
  PendingImportedHistoryReview(
    id: UUID(),
    studentID: StudentDemoSeed.studentID,
    family: family,
    pointIDs: [UUID()],
    reviewedMaxE1RM: 150,
    baseline1RMKg: 140,
    sourceWeightKg: 125,
    sourceReps: 5,
    sourceE1RMKg: 150
  )
}

private actor ChatRequestCountingRepository: ChatRepository {
  private(set) var requestCount = 0

  func fetchConversations() async throws -> [ChatConversation] {
    requestCount += 1
    return []
  }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    requestCount += 1
    return ChatConversation(
      id: UUID(),
      otherPartyID: otherPartyID,
      otherPartyName: "",
      lastMessagePreview: nil,
      lastMessageAt: nil,
      unreadCount: 0,
      myLastRead: nil,
      otherLastRead: nil
    )
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    requestCount += 1
    return ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
  }

  func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    requestCount += 1
    throw ChatRepositoryError.conversationNotFound
  }

  func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    requestCount += 1
    throw ChatRepositoryError.conversationNotFound
  }

  func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    requestCount += 1
    throw ChatRepositoryError.conversationNotFound
  }
}
