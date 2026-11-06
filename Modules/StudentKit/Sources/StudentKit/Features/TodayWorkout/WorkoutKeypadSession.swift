import DesignSystem
import Foundation
import Observation

/// One exercise's editable cells, ordered by the visible rows and fields.
@Observable @MainActor
final class WorkoutKeypadSession {
  private var cells: [WorkoutKeypadCell] = []
  private var index = 0
  private var onCommit: ((WorkoutKeypadCell, String) -> Void)?
  var panelTop: CGFloat = 0

  var current: WorkoutKeypadCell? { cells.indices.contains(index) ? cells[index] : nil }
  var next: WorkoutKeypadCell? { cells.indices.contains(index + 1) ? cells[index + 1] : nil }

  func field(for rowID: UUID) -> MeetPRNumberPad.Field? {
    current?.rowID == rowID ? current?.field : nil
  }

  func open(
    cells: [WorkoutKeypadCell], at id: WorkoutKeypadCell.Address,
    onCommit: @escaping (WorkoutKeypadCell, String) -> Void
  ) {
    guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
    self.cells = cells
    self.index = index
    self.onCommit = onCommit
  }

  func commit(_ text: String) {
    guard let current, NumberPadTextInput(value: text, field: current.field).isValid else { return }
    let normalized = NumberPadTextInput(value: text, field: current.field).committedText
    let value =
      text.isEmpty && (current.field == .weight || current.field == .reps)
      ? current.value : normalized
    onCommit?(current, value)
    index += 1
    if self.current == nil { cancel() }
  }

  func cancel() {
    cells = []
    index = 0
    onCommit = nil
    panelTop = 0
  }
}
