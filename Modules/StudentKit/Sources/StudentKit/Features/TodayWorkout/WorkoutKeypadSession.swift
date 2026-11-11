import DesignSystem
import Foundation
import Observation

/// One exercise's editable cells, ordered by the visible rows and fields.
@Observable @MainActor
final class WorkoutKeypadSession {
  private var cells: [WorkoutKeypadCell] = []
  private var index = 0
  private var onCommit: ((WorkoutKeypadCell, String) -> Void)?
  private var onChange: ((WorkoutKeypadCell, String?) -> Void)?
  private var editedText: String?
  private var allowsEmptyWeight = false
  var panelTop: CGFloat = 0
  private(set) var allowsBackgroundInteraction = false

  var current: WorkoutKeypadCell? { cells.indices.contains(index) ? cells[index] : nil }
  var previewText: String? { editedText ?? current?.value }
  var next: WorkoutKeypadCell? { cells.indices.contains(index + 1) ? cells[index + 1] : nil }

  func effortField(for rowID: UUID) -> MeetPRNumberPad.Field? {
    cells.first { $0.rowID == rowID && ($0.field == .rpe || $0.field == .rir) }?.field
  }

  func field(for rowID: UUID) -> MeetPRNumberPad.Field? {
    current?.rowID == rowID ? current?.field : nil
  }

  func open(
    cells: [WorkoutKeypadCell], at id: WorkoutKeypadCell.Address,
    onChange: ((WorkoutKeypadCell, String?) -> Void)? = nil,
    allowsEmptyWeight: Bool = false,
    allowsBackgroundInteraction: Bool = false,
    onCommit: @escaping (WorkoutKeypadCell, String) -> Void
  ) {
    guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
    self.cells = cells
    self.index = index
    self.onCommit = onCommit
    self.onChange = onChange
    self.allowsEmptyWeight = allowsEmptyWeight
    self.allowsBackgroundInteraction = allowsBackgroundInteraction
    editedText = nil
  }

  func update(_ text: String) {
    guard let current else { return }
    editedText = text
    onChange?(current, text)
  }

  func commit(_ text: String) {
    guard let current else { return }
    let input = NumberPadTextInput(value: text, field: current.field)
    guard input.isValid else { return }
    // An untouched cell only advances; it must not create a record.
    if editedText != nil || text != current.value {
      let value =
        text.isEmpty && (current.field == .reps || (current.field == .weight && !allowsEmptyWeight))
        ? current.value : input.committedText
      onCommit?(current, value)
    }
    editedText = nil
    index += 1
    if self.current == nil { reset() }
  }

  func dismiss() {
    guard let current else { return }
    if let text = editedText {
      let input = NumberPadTextInput(value: text, field: current.field)
      if !text.isEmpty && input.isValid {
        onCommit?(current, input.committedText)
      } else {
        onChange?(current, nil)
      }
    }
    reset()
  }

  /// Navigation/account teardown abandons the transient preview; it is not a pad dismissal.
  func cancel() {
    if let current, editedText != nil { onChange?(current, nil) }
    reset()
  }

  private func reset() {
    cells = []
    index = 0
    onCommit = nil
    onChange = nil
    editedText = nil
    panelTop = 0
    allowsEmptyWeight = false
    allowsBackgroundInteraction = false
  }
}
