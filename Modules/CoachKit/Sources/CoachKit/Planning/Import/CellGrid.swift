import Foundation

/// A single xlsx cell value (spec 043 §A). Dates are numeric serials; the
/// importer treats them as numbers (the plan is re-dated at import), so `date`
/// and `number` are interchangeable for geometry — both report `isNumeric`.
enum CellValue: Equatable, Sendable {
  case text(String)
  case number(Double)
  case date(Double)

  /// Trimmed string content for parsing; numbers render without trailing `.0`.
  var stringValue: String {
    switch self {
    case .text(let value):
      return value.trimmingCharacters(in: .whitespacesAndNewlines)
    case .number(let value), .date(let value):
      if value == value.rounded() { return String(Int(value)) }
      return String(value)
    }
  }

  var isNumeric: Bool {
    switch self {
    case .text:
      return false
    case .number, .date:
      return true
    }
  }
}

/// A 1-based sparse grid of cells read from one worksheet.
struct CellGrid: Equatable, Sendable {
  let maxRow: Int
  let maxCol: Int
  private let cells: [Coordinate: CellValue]

  struct Coordinate: Hashable, Sendable {
    let row: Int
    let col: Int
  }

  init(cells: [Coordinate: CellValue]) {
    self.cells = cells
    maxRow = cells.keys.map(\.row).max() ?? 0
    maxCol = cells.keys.map(\.col).max() ?? 0
  }

  /// Convenience for tests/fixtures: build from `(row, col, value)` triples.
  init(_ triples: [(row: Int, col: Int, value: CellValue)]) {
    var dict: [Coordinate: CellValue] = [:]
    for triple in triples {
      dict[Coordinate(row: triple.row, col: triple.col)] = triple.value
    }
    self.init(cells: dict)
  }

  /// 1-based cell access; `nil` for empty cells.
  func value(row: Int, col: Int) -> CellValue? {
    cells[Coordinate(row: row, col: col)]
  }

  /// Trimmed string at the cell, empty string when absent.
  func string(row: Int, col: Int) -> String {
    value(row: row, col: col)?.stringValue ?? ""
  }

  func isNumeric(row: Int, col: Int) -> Bool {
    value(row: row, col: col)?.isNumeric ?? false
  }
}
