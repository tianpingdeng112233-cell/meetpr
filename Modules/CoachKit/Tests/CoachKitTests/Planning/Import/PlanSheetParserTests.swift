import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 §C/§D — a desensitised 2-week grid exercising 续行 / 多行 / 休息 /
// 坏日期行 and full week→day→exercise→set structuring.

private struct GridBuilder {
  var offset = 1
  // swiftlint:disable:next large_tuple
  var triples: [(row: Int, col: Int, value: CellValue)] = []

  mutating func dateRow(_ row: Int, serialBase: Double) {
    for day in 0..<7 {
      triples.append(
        (
          row: row, col: PlanSheetGeometry.dayColumns(day, offset: offset).nameCol,
          value: .number(serialBase + Double(day))
        ))
    }
  }

  mutating func cell(
    row: Int, day: Int, name: String? = nil, sets: String? = nil, intensity: String? = nil,
    float1: String? = nil
  ) {
    let columns = PlanSheetGeometry.dayColumns(day, offset: offset)
    if let name { triples.append((row: row, col: columns.nameCol, value: .text(name))) }
    if let sets { triples.append((row: row, col: columns.setsCol, value: .text(sets))) }
    if let intensity {
      triples.append((row: row, col: columns.intensityCol, value: .text(intensity)))
    }
    if let float1 { triples.append((row: row, col: columns.float1Col, value: .text(float1))) }
  }
}

private func makeFixtureGrid() -> CellGrid {
  var builder = GridBuilder()
  // Week 1 header (valid serials).
  builder.dateRow(1, serialBase: 45_000)
  // Day 0: main lift + a continuation backoff set on the next row.
  builder.cell(row: 2, day: 0, name: "低杠深蹲", sets: "4*3", intensity: "D100/L110 递增5kg")
  builder.cell(row: 3, day: 0, sets: "1*1", intensity: "减10kg*1")  // 续行
  // Day 1: rest.
  builder.cell(row: 2, day: 1, name: "休息")
  // Day 2: multi-line accessory cell → two exercises.
  builder.cell(row: 2, day: 2, name: "二头弯举\n三头下压", sets: "3*12", intensity: "rpe8")

  // Week 2 header (corrupt out-of-range serials — 坏日期行).
  builder.dateRow(5, serialBase: 45_656)
  builder.cell(row: 6, day: 0, name: "卧推", sets: "5*5", intensity: "100")

  return CellGrid(builder.triples)
}

@Test func parsesTwoWeekFixtureStructure() {
  let plan = PlanSheetParser.parse(makeFixtureGrid())
  #expect(plan.weeks.count == 2)

  let week1Day0 = plan.weeks[0].days[0]
  #expect(week1Day0.exercises.count == 1)
  #expect(week1Day0.exercises[0].rawName == "低杠深蹲")
  // 4 ladder sets + 1 continuation backoff set.
  #expect(week1Day0.exercises[0].sets.count == 5)
  #expect(week1Day0.exercises[0].sets[0].weightKg == Decimal(string: "100"))
  #expect(week1Day0.exercises[0].sets[4].setType == .backoff)
  #expect(week1Day0.exercises[0].sets[4].coachNote == "减10kg*1")
}

@Test func restDayHasNoExercises() {
  let plan = PlanSheetParser.parse(makeFixtureGrid())
  let week1Day1 = plan.weeks[0].days[1]
  #expect(week1Day1.isRest)
  #expect(week1Day1.exercises.isEmpty)
}

@Test func multiLineCellSplitsIntoAccessories() {
  let plan = PlanSheetParser.parse(makeFixtureGrid())
  let week1Day2 = plan.weeks[0].days[2]
  #expect(week1Day2.exercises.map(\.rawName) == ["二头弯举", "三头下压"])
  #expect(week1Day2.exercises.allSatisfy { $0.sets.count == 3 })
  #expect(week1Day2.exercises[0].sets.allSatisfy { $0.rpe == Decimal(8) })
}

@Test func corruptDateRowSecondWeekStillParses() {
  let plan = PlanSheetParser.parse(makeFixtureGrid())
  #expect(plan.weeks[1].blockIndex == 1)
  let week2Day0 = plan.weeks[1].days[0]
  #expect(week2Day0.exercises.first?.rawName == "卧推")
  #expect(week2Day0.exercises.first?.sets.count == 5)
}

@Test func parsesRightShiftedSheetAtDetectedOffset() {
  // 邓天平.xlsx: the whole day grid is one column to the right (offset 2). The
  // locked offset-1 geometry saw 0 weeks here; detection must pick offset 2.
  var builder = GridBuilder(offset: 2)
  builder.dateRow(1, serialBase: 46_020)
  builder.cell(row: 2, day: 0, name: "传统硬拉", sets: "3*5")
  builder.cell(row: 2, day: 3, name: "深蹲", sets: "1*5", intensity: "150")
  let plan = PlanSheetParser.parse(CellGrid(builder.triples))

  #expect(plan.weeks.count == 1)
  #expect(plan.weeks[0].days[0].exercises.map(\.rawName) == ["传统硬拉"])
  #expect(plan.weeks[0].days[0].exercises.first?.sets.count == 3)
  #expect(plan.weeks[0].days[3].exercises.first?.rawName == "深蹲")
}
