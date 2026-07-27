import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func newPlanNoticePersistsSeenState() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let seenStore = InMemoryDashboardPlanSeenStore()
  let viewModel = DashboardNotificationsViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    seenStore: seenStore
  )

  await viewModel.load(studentID: studentID)
  #expect(viewModel.planNotice?.weekIndex == plan.weekIndex)
  #expect(viewModel.hasUnread(feedbackUnreadCount: 0))

  viewModel.markCurrentPlanSeen()
  #expect(viewModel.planNotice == nil)
  #expect(!viewModel.hasUnread(feedbackUnreadCount: 0))

  await viewModel.load(studentID: studentID)
  #expect(viewModel.planNotice == nil)
}

@MainActor
@Test func notificationAggregationIncludesExistingUnreadSignals() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let seenStore = InMemoryDashboardPlanSeenStore()
  seenStore.markSeen(studentID: studentID, signature: DashboardPlanSignature(plan: plan))
  let viewModel = DashboardNotificationsViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    seenStore: seenStore
  )

  await viewModel.load(studentID: studentID)

  #expect(!viewModel.hasUnread(feedbackUnreadCount: 0))
  #expect(viewModel.hasUnread(feedbackUnreadCount: 1))
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

  // A fresh instance over the same suite still reads it back (real persistence).
  #expect(
    UserDefaultsDashboardPlanSeenStore(defaults: defaults)
      .hasSeen(studentID: studentA, signature: signature)
  )
  // A different student and a different plan signature are isolated.
  #expect(!store.hasSeen(studentID: studentB, signature: signature))
  let otherSignature = DashboardPlanSignature(plan: StudentDemoSeed.makePlanView(weekIndex: 2))
  #expect(!store.hasSeen(studentID: studentA, signature: otherSignature))
}
