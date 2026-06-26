import Foundation

// Grid geometry of 吕子豪's xlsx, measured and locked (spec 043 §B). 7 days run
// across the columns, 5 columns per day; week blocks are separated by a date row
// (each day's name column holds a date serial) with a blank row between blocks.

/// 1-based absolute columns for one day (0-based `dayIndex` 0…6).
struct DayColumns: Equatable, Sendable {
  let dayIndex: Int
  let nameCol: Int
  let setsCol: Int
  let intensityCol: Int
  let float1Col: Int
  let float2Col: Int
}

/// A contiguous week block: the date (header) row plus its content rows.
struct WeekBlock: Equatable, Sendable {
  let blockIndex: Int
  let headerRow: Int
  let dateSerials: [Double?]
  let contentRows: [Int]
}

enum PlanSheetGeometry {
  static let daysPerWeek = 7
  static let columnsPerDay = 5

  /// Day `d` occupies absolute columns `[1 + 5d … 5 + 5d]`.
  static func dayColumns(_ dayIndex: Int) -> DayColumns {
    let base = 1 + dayIndex * columnsPerDay
    return DayColumns(
      dayIndex: dayIndex,
      nameCol: base,
      setsCol: base + 1,
      intensityCol: base + 2,
      float1Col: base + 3,
      float2Col: base + 4
    )
  }

  /// A date/header row: enough of the day name-columns hold a numeric serial.
  /// Detection is structural (numeric vs text), not value-based, so a corrupt
  /// out-of-range date (spec §B 坏日期行) is still recognised as a week start.
  static func isDateRow(_ grid: CellGrid, row: Int) -> Bool {
    var numericNameCols = 0
    for day in 0..<daysPerWeek where grid.isNumeric(row: row, col: dayColumns(day).nameCol) {
      numericNameCols += 1
    }
    return numericNameCols >= 3
  }

  /// Whether the row has no content across the whole 7-day span.
  static func isBlankRow(_ grid: CellGrid, row: Int) -> Bool {
    for day in 0..<daysPerWeek {
      let columns = dayColumns(day)
      for col in columns.nameCol...columns.float2Col where grid.value(row: row, col: col) != nil {
        return false
      }
    }
    return true
  }

  /// Segments the sheet into week blocks. A date row opens a block; the block's
  /// content rows are the non-blank rows up to (but excluding) the next date row.
  static func weekBlocks(in grid: CellGrid) -> [WeekBlock] {
    guard grid.maxRow > 0 else { return [] }

    var headerRows: [Int] = []
    for row in 1...grid.maxRow where isDateRow(grid, row: row) {
      headerRows.append(row)
    }
    guard !headerRows.isEmpty else { return [] }

    var blocks: [WeekBlock] = []
    for (blockIndex, headerRow) in headerRows.enumerated() {
      let nextHeader =
        blockIndex + 1 < headerRows.count ? headerRows[blockIndex + 1] : grid.maxRow + 1
      let contentRows = ((headerRow + 1)..<nextHeader).filter { !isBlankRow(grid, row: $0) }
      let serials = (0..<daysPerWeek).map { day -> Double? in
        switch grid.value(row: headerRow, col: dayColumns(day).nameCol) {
        case .number(let value), .date(let value):
          return value
        default:
          return nil
        }
      }
      blocks.append(
        WeekBlock(
          blockIndex: blockIndex,
          headerRow: headerRow,
          dateSerials: serials,
          contentRows: contentRows
        )
      )
    }
    return blocks
  }
}
