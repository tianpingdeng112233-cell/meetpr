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

  static func abnormalReason(_ reason: AbnormalReason) -> String {
    switch reason {
    case .noTrainingForDays(let days):
      "\(days) 天未训练"
    case .stuckOnWeek(let week):
      "卡 W\(week) 未完成"
    }
  }
}
