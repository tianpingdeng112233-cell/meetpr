import CoreModels
import Foundation

// Walks the worksheet grid into a `ParsedPlan` using the locked geometry and the
// set-line rules (spec 043 §C/§D). Per day it reads top-to-bottom: a name cell
// opens an exercise; an empty name with a 组次/强度 continues the previous one
// (续行); `休息` marks a rest day; a multi-line name cell splits into accessories.

enum PlanSheetParser {
  static let restMarker = "休息"

  static func parse(_ grid: CellGrid) -> ParsedPlan {
    let offset = PlanSheetGeometry.detectDayOffset(in: grid)
    let blocks = PlanSheetGeometry.weekBlocks(in: grid, offset: offset)
    let weeks = blocks.map { block in
      ParsedWeek(
        blockIndex: block.blockIndex,
        dateSerials: block.dateSerials,
        days: (0..<PlanSheetGeometry.daysPerWeek).map { day in
          parseDay(dayIndex: day, offset: offset, block: block, grid: grid)
        }
      )
    }
    return ParsedPlan(weeks: weeks)
  }

  private static func parseDay(
    dayIndex: Int, offset: Int, block: WeekBlock, grid: CellGrid
  ) -> ParsedDay {
    let columns = PlanSheetGeometry.dayColumns(dayIndex, offset: offset)
    var exercises: [ParsedExercise] = []
    var isRest = false

    for row in block.contentRows {
      let name = grid.string(row: row, col: columns.nameCol)
      let setsCell = grid.string(row: row, col: columns.setsCol)
      let intensityCell = grid.string(row: row, col: columns.intensityCol)
      let float1 = grid.string(row: row, col: columns.float1Col)
      let float2 = grid.string(row: row, col: columns.float2Col)

      if name == restMarker {
        isRest = true
        continue
      }

      let hasSetContent = !setsCell.isEmpty || !intensityCell.isEmpty
      if name.isEmpty {
        guard hasSetContent else { continue }
        // 续行: append to the day's last exercise.
        guard !exercises.isEmpty else { continue }
        let extra = SetLineParser.expand(
          setsCell: setsCell,
          intensityCell: intensityCell,
          float1: float1,
          float2: float2,
          exerciseName: exercises[exercises.count - 1].rawName
        )
        exercises[exercises.count - 1].sets.append(contentsOf: extra)
        continue
      }

      // Multi-line name cell → one accessory per line, sharing the row's sets.
      let lines = name.split(whereSeparator: { $0.isNewline }).map(String.init)
      let names = lines.count > 1 ? lines : [name]
      for line in names {
        let (cleanName, tempoNote) = SetLineParser.stripTempoSuffix(line)
        var sets = SetLineParser.expand(
          setsCell: setsCell,
          intensityCell: intensityCell,
          float1: float1,
          float2: float2,
          exerciseName: cleanName
        )
        if let tempoNote {
          for index in sets.indices where sets[index].coachNote == nil {
            sets[index].coachNote = tempoNote
          }
        }
        exercises.append(ParsedExercise(rawName: cleanName, sets: sets))
      }
    }

    return ParsedDay(dayOfWeek: dayIndex, isRest: isRest, exercises: exercises)
  }
}
