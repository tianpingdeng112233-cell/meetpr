import Foundation
import Testing

@testable import CoachKit

// spec 043 §B — 7×5 stride addressing and date-row driven week-block splitting.

@Test func dayColumnsUseFiveColumnStride() {
  let day0 = PlanSheetGeometry.dayColumns(0)
  #expect(
    (day0.nameCol, day0.setsCol, day0.intensityCol, day0.float1Col, day0.float2Col) == (
      1, 2, 3, 4, 5
    ))

  let day6 = PlanSheetGeometry.dayColumns(6)
  #expect((day6.nameCol, day6.float2Col) == (31, 35))
}

// swiftlint:disable:next large_tuple
private func dateRow(_ row: Int, serialBase: Double) -> [(row: Int, col: Int, value: CellValue)] {
  (0..<7).map { day in
    (
      row: row, col: PlanSheetGeometry.dayColumns(day).nameCol,
      value: CellValue.number(serialBase + Double(day))
    )
  }
}

@Test func detectsDateRowsAndSplitsBlocks() {
  // swiftlint:disable:next large_tuple
  var triples: [(row: Int, col: Int, value: CellValue)] = []
  // Week 1 header at row 1, content at row 2; blank row 3; week 2 header row 4.
  triples += dateRow(1, serialBase: 45_000)
  triples.append((row: 2, col: 1, value: .text("低杠深蹲")))
  triples.append((row: 2, col: 2, value: .text("4*3")))
  triples += dateRow(4, serialBase: 45_007)
  triples.append((row: 5, col: 1, value: .text("卧推")))
  triples.append((row: 5, col: 2, value: .text("3*5")))
  let grid = CellGrid(triples)

  #expect(PlanSheetGeometry.isDateRow(grid, row: 1))
  #expect(!PlanSheetGeometry.isDateRow(grid, row: 2))
  #expect(PlanSheetGeometry.isBlankRow(grid, row: 3))

  let blocks = PlanSheetGeometry.weekBlocks(in: grid)
  #expect(blocks.count == 2)
  #expect(blocks[0].headerRow == 1)
  #expect(blocks[0].contentRows == [2])
  #expect(blocks[1].headerRow == 4)
  #expect(blocks[1].contentRows == [5])
}

@Test func corruptDateRowStillOpensABlock() {
  // 坏日期行: out-of-range serials, still structurally a date row.
  var triples = dateRow(1, serialBase: 45_656)  // ~2024-12-30, implausible
  triples.append((row: 2, col: 1, value: .text("深蹲")))
  triples.append((row: 2, col: 2, value: .text("5*5")))
  let grid = CellGrid(triples)

  #expect(PlanSheetGeometry.isDateRow(grid, row: 1))
  #expect(PlanSheetGeometry.weekBlocks(in: grid).count == 1)
}
