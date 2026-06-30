import Foundation
import Testing

@testable import CoachKit

// spec 043 hardening — sheet selection is structural + recency-based, not a
// hardcoded name ignore-list (邓天平.xlsx keeps the current plan in a sheet named
// "2026"; the old locked list ignored that name and grabbed last year's "2025").

private func planSheet(serialBase: Double, offset: Int = 1) -> CellGrid {
  // swiftlint:disable:next large_tuple
  var triples: [(row: Int, col: Int, value: CellValue)] = []
  for day in 0..<7 {
    triples.append((row: 1, col: offset + day * 5, value: .number(serialBase + Double(day))))
  }
  triples.append((row: 2, col: offset, value: .text("深蹲")))
  triples.append((row: 2, col: offset + 1, value: .text("4*8")))
  return CellGrid(triples)
}

@Test func selectsSheetWithMostRecentDatesRegardlessOfName() {
  let notes = CellGrid([(row: 1, col: 1, value: .text("注意事项"))])
  let plan2026 = planSheet(serialBase: 46_020, offset: 2)  // current, right-shifted
  let plan2025 = planSheet(serialBase: 45_929)  // last year

  let selected = PlanSheetSelector.selectPlanSheet(from: [
    ("注意事项", notes), ("2026", plan2026), ("2025", plan2025),
  ])

  #expect(selected == plan2026)
}

@Test func ignoresDateOnlySheetWithoutTrainingContent() {
  // A year skeleton or notes sheet can hold the newest dates yet no exercises; it
  // must not win over an older sheet that actually has training rows (else the
  // builder drops everything and the coach lands in an empty review).
  let skeleton = CellGrid(
    (0..<7).map { (row: 1, col: 1 + $0 * 5, value: CellValue.text("\(47_000 + $0)")) })
  let plan = planSheet(serialBase: 45_000)  // older dates, but has a 深蹲 content row

  let selected = PlanSheetSelector.selectPlanSheet(from: [
    ("skeleton", skeleton), ("plan", plan),
  ])

  #expect(selected == plan)
}

@Test func picksNewerSheetWhenSerialsAreTextTyped() {
  // WPS delivers serials as text; recency must rank them numerically, not lexically.
  func textPlan(_ base: Int) -> CellGrid {
    // swiftlint:disable:next large_tuple
    var triples: [(row: Int, col: Int, value: CellValue)] =
      (0..<7).map { (row: 1, col: 1 + $0 * 5, value: CellValue.text("\(base + $0)")) }
    triples.append((row: 2, col: 1, value: .text("深蹲")))
    triples.append((row: 2, col: 2, value: .text("4*8")))
    return CellGrid(triples)
  }
  let older = textPlan(45_900)
  let newer = textPlan(46_020)

  #expect(PlanSheetSelector.selectPlanSheet(from: [("a", older), ("b", newer)]) == newer)
}

@Test func selectsNilWhenNoSheetHasWeekStructure() {
  let notes = CellGrid([(row: 1, col: 1, value: .text("注意事项"))])
  #expect(PlanSheetSelector.selectPlanSheet(from: [("注意事项", notes)]) == nil)
}
