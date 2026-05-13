import CoreModels
import Foundation

enum PlanningDisplay {
  static func liftName(_ family: LiftFamily) -> String {
    switch family {
    case .squat:
      "深蹲"
    case .bench:
      "卧推"
    case .deadlift:
      "硬拉"
    }
  }

  static func weekdayName(_ dayOfWeek: Int) -> String {
    switch dayOfWeek {
    case 1:
      "周一"
    case 2:
      "周二"
    case 3:
      "周三"
    case 4:
      "周四"
    case 5:
      "周五"
    case 6:
      "周六"
    case 7:
      "周日"
    default:
      "第 \(dayOfWeek) 天"
    }
  }

  static func compactWeekdays(_ days: [Int]) -> String {
    days.sorted().map(weekdayName).joined(separator: "·")
  }

  // swiftlint:disable:next cyclomatic_complexity
  static func muscleGroupName(_ muscleGroup: MuscleGroup) -> String {
    switch muscleGroup {
    case .chest:
      "胸"
    case .shoulder:
      "肩"
    case .back:
      "背"
    case .biceps:
      "二头"
    case .triceps:
      "三头"
    case .forearm:
      "前臂"
    case .core:
      "核心"
    case .quad:
      "股四"
    case .hamstring:
      "腘绳"
    case .glute:
      "臀"
    case .hip:
      "髋"
    case .hipFlexor:
      "屈髋"
    case .adductor:
      "内收"
    case .calf:
      "小腿"
    case .tibialis:
      "胫前"
    case .trap:
      "斜方"
    case .mobility:
      "活动度"
    case .cardio:
      "心肺"
    case .grip:
      "握力"
    }
  }

  static func equipmentName(_ equipment: Equipment) -> String {
    switch equipment {
    case .barbell:
      "杠铃"
    case .dumbbell:
      "哑铃"
    case .machine:
      "器械"
    case .bodyweight:
      "自重"
    case .cable:
      "绳索"
    case .band:
      "弹力带"
    case .kettlebell:
      "壶铃"
    case .specialtyBar:
      "特殊杆"
    case .other:
      "其他"
    }
  }

  static func movementPatternName(_ movementPattern: MovementPattern) -> String {
    switch movementPattern {
    case .squat:
      "蹲"
    case .horizontalPush:
      "水平推"
    case .verticalPush:
      "垂直推"
    case .hipHinge:
      "髋铰链"
    case .horizontalPull:
      "水平拉"
    case .verticalPull:
      "垂直拉"
    case .other:
      "其他"
    }
  }

  static func facetSummary(for exercise: Exercise) -> String {
    let muscleGroups = exercise.muscleGroups.map(muscleGroupName).joined(separator: " + ")
    let equipment = exercise.equipment.map(equipmentName).joined(separator: " + ")
    let movementPattern = exercise.movementPattern.map(movementPatternName).joined(separator: " + ")
    return [muscleGroups, equipment, movementPattern]
      .filter { !$0.isEmpty }
      .joined(separator: " / ")
  }

  static func abnormalReason(_ reason: AbnormalReason) -> String {
    switch reason {
    case .noTrainingForDays(let days):
      "\(days) 天未训练"
    case .stuckOnWeek(let week):
      "卡 W\(week) 未完成"
    }
  }
}
