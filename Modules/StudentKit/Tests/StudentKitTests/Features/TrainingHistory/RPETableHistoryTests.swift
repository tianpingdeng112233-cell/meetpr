import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct RPETableHistoryTests {
  @Test func headerRoundsInTheDisplayedUnit() {
    #expect(RPETable.headerText(e1RM: 178.3479349186484, unit: .kg) == "178.3")
    #expect(RPETable.headerText(e1RM: 92.5 / 0.81, unit: .kg) == "114.2")
    #expect(RPETable.headerText(e1RM: 180, unit: .kg) == "180")
    #expect(RPETable.headerText(e1RM: 92.5 / 0.81, unit: .lb) == "251.8")
    #expect(RPETable.headerText(e1RM: 100, unit: .lb) == "220.5")
    #expect(RPETable.headerText(e1RM: 90.72, unit: .lb) == "200")
    #expect(RPETable.headerText(e1RM: nil, unit: .lb) == "100%")
  }

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
