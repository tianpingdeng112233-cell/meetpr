import CoreModels
import Foundation
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
