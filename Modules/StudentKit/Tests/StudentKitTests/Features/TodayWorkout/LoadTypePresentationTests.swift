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

@MainActor
@Test func bodyweightCardUsesCompactRowsWithOneWeightCaption() async throws {
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  var drafts = try #require(fixture.model.currentDrafts)
  for index in drafts.indices {
    drafts[index].prescribed = PrescribedSet(
      id: drafts[index].id, setIndex: index, loadMode: .bodyweight, reps: 10)
  }
  let presentation = TodayWorkoutPresentation(
    day: fixture.day, drafts: drafts, references: [:], started: true)
  let card = AccessoryLogCard(
    exercise: try #require(presentation.exercises.first), viewModel: fixture.model,
    unit: .kg, previousLogs: [:], onEdit: { _ in })
  #expect(try card.inspect().findAll(AccessoryLogRow.self).count == 3)
  #expect(try card.inspect().findAll(LoadTypeLogRow.self).isEmpty)
  let captions = try card.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
  #expect(
    captions.filter { $0 == StudentStrings.replacing(.loadTypeExtraWeight, values: ["kg"]) }.count
      == 1)
  #expect(!captions.contains(StudentStrings.localized(.loadTypeBodyweightHint)))
}

@MainActor
@Test func bodyweightCompactRowsUseTheHeaderUnitAlongsideFixedRows() async throws {
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  var drafts = try #require(fixture.model.currentDrafts)
  for index in drafts.indices {
    drafts[index].prescribed = PrescribedSet(
      id: drafts[index].id, setIndex: index,
      loadMode: index == 0 ? .fixedWeight : .bodyweight, reps: 10)
  }
  let presentation = TodayWorkoutPresentation(
    day: fixture.day, drafts: drafts, references: [:], started: true)
  let card = AccessoryLogCard(
    exercise: try #require(presentation.exercises.first), viewModel: fixture.model,
    unit: .lb, previousLogs: [:], onEdit: { _ in })
  let rows = try card.inspect().findAll(AccessoryLogRow.self)
  #expect(rows.count == 3)
  for inspectedRow in rows {
    var row = try inspectedRow.actualView().row
    #expect(row.unit == .lb)
    row.input.weight = "10"
    #expect(row.weightKg == UnitDisplay.rounded(10 / UnitDisplay.lbPerKg, scale: 2))
  }
  let captions = try card.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
  #expect(captions.contains("LB"))
  #expect(captions.contains("额外负重 lb"))
}
