import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct RPETableHistoryTests {
  @Test func existingFamilyHistoryRemainsAvailableWithoutCurrentPlan() async throws {
    let studentID = UUID()
    let history = InMemoryE1RMRepository(seedPoints: [
      .init(
        id: UUID(), studentId: studentID, exerciseId: UUID(), family: .bench,
        setLogId: UUID(), computedAt: Date(), e1RMKg: 120,
        sourceWeightKg: 100, sourceReps: 3, sourceRPE: 8)
    ])
    let model = ProgressDataModel(
      studentID: studentID,
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [:])),
      logs: InMemoryStudentTrainingLogRepository(), e1rm: history, onboarding: nil, feedback: nil)
    let snapshot = try await model.rpeTableSnapshot()
    #expect(snapshot.defaultFamily == .squat)
    #expect(snapshot.e1RM[.bench] == 120)
  }
}
