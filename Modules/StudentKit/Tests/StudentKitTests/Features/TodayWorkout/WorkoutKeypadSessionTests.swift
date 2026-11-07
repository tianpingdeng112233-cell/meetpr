import DesignSystem
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct WorkoutKeypadSessionTests {
  @Test func advancesAcrossRowsAndSkipsUnavailableFields() {
    let first = UUID()
    let second = UUID()
    let session = WorkoutKeypadSession()
    var values: [String] = []
    let cells = [
      WorkoutKeypadCell(rowID: first, field: .weight, value: "20"),
      WorkoutKeypadCell(rowID: first, field: .reps, value: "8"),
      WorkoutKeypadCell(rowID: first, field: .rpe, value: ""),
      WorkoutKeypadCell(rowID: second, field: .reps, value: "10"),
      WorkoutKeypadCell(rowID: second, field: .rir, value: "2"),
    ]
    session.open(cells: cells, at: cells[0].id) { _, value in values.append(value) }
    session.commit("7.5")
    #expect(session.current?.field == .reps)
    session.commit("12")
    #expect(session.current?.field == .rpe)
    session.commit("9.5")
    #expect(session.current?.rowID == second)
    #expect(session.current?.field == .reps)
    session.commit("10")
    #expect(session.next == nil)
    session.commit("0")
    #expect(session.current == nil)
    #expect(values == ["7.5", "12", "9.5", "10", "0"])
  }
  @Test func cancelAndEmptyCommitsPreserveRequiredFieldsAndClearEffort() {
    let session = WorkoutKeypadSession()
    let rowID = UUID()
    var values: [String] = []
    let cells = [
      WorkoutKeypadCell(rowID: rowID, field: .weight, value: "7.5"),
      WorkoutKeypadCell(rowID: rowID, field: .reps, value: "8"),
      WorkoutKeypadCell(rowID: rowID, field: .rpe, value: "9.5"),
      WorkoutKeypadCell(rowID: UUID(), field: .rir, value: "2"),
    ]
    session.open(cells: cells, at: cells[0].id) { _, value in values.append(value) }
    session.cancel()
    #expect(values.isEmpty)
    #expect(session.current == nil)
    session.open(cells: cells, at: cells[0].id) { _, value in values.append(value) }
    for _ in cells { session.commit("") }
    #expect(values == ["7.5", "8", "", ""])
    #expect(session.current == nil)
  }

  @Test func invalidValueDoesNotAdvanceOrCommit() {
    let session = WorkoutKeypadSession()
    let cell = WorkoutKeypadCell(rowID: UUID(), field: .rpe, value: "8")
    var value: String?
    session.open(cells: [cell], at: cell.id) { _, text in value = text }
    session.commit("10.5")
    #expect(session.current?.id == cell.id)
    #expect(value == nil)
  }
  @Test func realRowCellsPreserveUnitsSkipEffortAndSaveTrailingDecimal() async throws {
    let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .lb)
    let loadCells = WorkoutKeypadCell.cells(row: row, name: "Row", number: 2, includesEffort: false)
    #expect(loadCells.map(\.field) == [.weight, .reps])
    #expect(loadCells.first?.unit == "LB")
    row.input.effortMode = .rir
    let cells = WorkoutKeypadCell.cells(row: row, name: "Row", number: 2, includesEffort: true)
    #expect(cells.map(\.field) == [.weight, .reps, .rir])
    let session = WorkoutKeypadSession()
    session.open(cells: cells, at: cells[0].id) { cell, value in
      row.setKeypadValue(value, field: cell.field)
    }
    session.commit("7.")
    #expect(row.input.weight == "7")
    #expect(row.isWritable)
    session.commit("100")
    #expect(session.current?.id.field == .reps)
    session.commit("99")
    #expect(row.reps == 99)
    session.commit("0")
    #expect(row.rir == 0)
    #expect(session.current == nil)
  }
}
