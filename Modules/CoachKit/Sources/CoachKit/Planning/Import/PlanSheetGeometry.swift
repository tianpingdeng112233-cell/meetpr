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

  /// Excel date serials sit far above any training number (reps/weight/RPE/%), so a
  /// large numeric cell is what marks a date header — robust even when WPS delivers
  /// the serial as text (then everything parses numeric). 10_000 ≈ year 1927; every
  /// real plan date clears it, no rep/weight/percentage reaches it.
  static let minimumDateSerial = 10_000.0

  /// Whether the cell holds a value large enough to be a date serial (not a rep,
  /// weight, or RPE that merely parses as a number).
  static func isDateCell(_ grid: CellGrid, row: Int, col: Int) -> Bool {
    guard let value = grid.numericValue(row: row, col: col) else { return false }
    return value >= minimumDateSerial
  }

  /// Day `d` occupies columns `[offset + 5d … offset + 4 + 5d]`. `offset` is where
  /// day 0 begins — 1 for 吕子豪's locked grid, 2 for 邓天平's right-shifted one.
  static func dayColumns(_ dayIndex: Int, offset: Int = 1) -> DayColumns {
    let base = offset + dayIndex * columnsPerDay
    return DayColumns(
      dayIndex: dayIndex,
      nameCol: base,
      setsCol: base + 1,
      intensityCol: base + 2,
      float1Col: base + 3,
      float2Col: base + 4
    )
  }

  /// Detected 1-based column where day 0 begins. Different coaches start the day
  /// grid in different columns (吕子豪 at A=1, 邓天平 at B=2), so the offset is
  /// inferred structurally: the candidate offset whose name-columns yield the most
  /// date rows wins. Ties favour the smaller offset; an empty grid defaults to 1.
  static func detectDayOffset(in grid: CellGrid) -> Int {
    guard !grid.occupiedRows.isEmpty else { return 1 }
    var bestOffset = 1
    var bestCount = -1
    for offset in 1...columnsPerDay {
      var dateRows = 0
      for row in grid.occupiedRows {
        var numericNameCols = 0
        for day in 0..<daysPerWeek
        where isDateCell(grid, row: row, col: offset + day * columnsPerDay) {
          numericNameCols += 1
        }
        if numericNameCols >= 3 { dateRows += 1 }
      }
      if dateRows > bestCount {
        bestCount = dateRows
        bestOffset = offset
      }
    }
    return bestOffset
  }

  /// A date/header row: enough of the day name-columns hold a numeric serial.
  /// Detection is structural (numeric vs text), not value-based, so a corrupt
  /// out-of-range date (spec §B 坏日期行) is still recognised as a week start.
  static func isDateRow(_ grid: CellGrid, row: Int, offset: Int = 1) -> Bool {
    var numericNameCols = 0
    for day in 0..<daysPerWeek
    where isDateCell(grid, row: row, col: dayColumns(day, offset: offset).nameCol) {
      numericNameCols += 1
    }
    return numericNameCols >= 3
  }

  /// Whether the row has no content across the whole 7-day span.
  static func isBlankRow(_ grid: CellGrid, row: Int, offset: Int = 1) -> Bool {
    for day in 0..<daysPerWeek {
      let columns = dayColumns(day, offset: offset)
      for col in columns.nameCol...columns.float2Col where grid.value(row: row, col: col) != nil {
        return false
      }
    }
    return true
  }

  /// Segments the sheet into week blocks. A date row opens a block; the block's
  /// content rows are the non-blank rows up to (but excluding) the next date row.
  static func weekBlocks(in grid: CellGrid, offset: Int = 1) -> [WeekBlock] {
    guard !grid.occupiedRows.isEmpty else { return [] }

    var headerRows: [Int] = []
    for row in grid.occupiedRows where isDateRow(grid, row: row, offset: offset) {
      headerRows.append(row)
    }
    guard !headerRows.isEmpty else { return [] }

    var blocks: [WeekBlock] = []
    for (blockIndex, headerRow) in headerRows.enumerated() {
      let nextHeader =
        blockIndex + 1 < headerRows.count ? headerRows[blockIndex + 1] : grid.maxRow + 1
      let contentRows = grid.occupiedRows.filter {
        $0 > headerRow && $0 < nextHeader && !isBlankRow(grid, row: $0, offset: offset)
      }
      let serials = (0..<daysPerWeek).map { day in
        grid.numericValue(row: headerRow, col: dayColumns(day, offset: offset).nameCol)
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
