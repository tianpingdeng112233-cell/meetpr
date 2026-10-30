import CoreModels
import Foundation
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func loadTypeCardKeepsEveryPerSetIntensityTarget() async throws {
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  var drafts = try #require(fixture.model.currentDrafts)
  for index in drafts.indices {
    drafts[index].prescribed = PrescribedSet(
      id: drafts[index].id, setIndex: index, intensity: .rpe(Decimal(7 + index)),
      loadMode: .freeWeight, reps: 15)
  }
  let presentation = TodayWorkoutPresentation(
    day: fixture.day, drafts: drafts, references: [:], started: true)
  let card = AccessoryLogCard(
    exercise: try #require(presentation.exercises.first), viewModel: fixture.model,
    unit: .kg, previousLogs: [:], onEdit: { _ in })
  let headers = try card.inspect().findAll(LoadTypePrescriptionHeader.self)
  #expect(headers.count == 3)
  #expect(try headers.map { try $0.actualView().set.intensity } == [.rpe(7), .rpe(8), .rpe(9)])
  #expect(try headers.map { try $0.actualView().count } == [1, 1, 1])
}
