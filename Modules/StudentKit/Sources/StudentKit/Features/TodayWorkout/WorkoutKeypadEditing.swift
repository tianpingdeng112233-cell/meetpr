import Foundation

extension WorkoutKeypadSession {
  /// Preview the active cell while retaining the last accepted local row for invalid dismissal.
  func edit(
    cells: [WorkoutKeypadCell], rows: [AccessoryRow], at address: WorkoutKeypadCell.Address,
    onChange: @escaping (AccessoryRow) -> Void
  ) {
    var accepted = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    open(
      cells: cells, at: address,
      onChange: { cell, text in
        guard var row = accepted[cell.rowID] else { return }
        if let text { row.setKeypadValue(text, field: cell.field) }
        onChange(row)
      },
      onCommit: { cell, value in
        guard var row = accepted[cell.rowID] else { return }
        row.setKeypadValue(value, field: cell.field)
        accepted[cell.rowID] = row
        onChange(row)
      })
  }
}
