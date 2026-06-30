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

  /// Numeric value parsed from the string content, regardless of how the source
  /// typed the cell. WPS Office stores numbers (including date serials) as strings,
  /// so type-based `isNumeric` misses them; this reads the value either way and is
  /// nil only for genuinely non-numeric text (`传统硬拉`, `2*10`, `rpe`).
  var numericValue: Double? {
    Double(stringValue)
  }
}

/// A 1-based sparse grid of cells read from one worksheet.
struct CellGrid: Equatable, Sendable {
  let maxRow: Int
  let maxCol: Int
  /// Sorted, unique row indexes holding at least one cell. Geometry scans these
  /// instead of `1...maxRow` so a sparse far-down cell can't force a huge empty scan
  /// on every sheet.
  let occupiedRows: [Int]
  private let cells: [Coordinate: CellValue]

  struct Coordinate: Hashable, Sendable {
    let row: Int
    let col: Int
  }

  init(cells: [Coordinate: CellValue]) {
    self.cells = cells
    maxRow = cells.keys.map(\.row).max() ?? 0
    maxCol = cells.keys.map(\.col).max() ?? 0
    occupiedRows = Set(cells.keys.map(\.row)).sorted()
  }

  /// Convenience for tests/fixtures: build from `(row, col, value)` triples.
  init(_ triples: [(row: Int, col: Int, value: CellValue)]) {  // swiftlint:disable:this large_tuple
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

  /// Numeric value at the cell parsed from its string content (WPS-tolerant); nil
  /// for empty or non-numeric cells.
  func numericValue(row: Int, col: Int) -> Double? {
    value(row: row, col: col)?.numericValue
  }
}
