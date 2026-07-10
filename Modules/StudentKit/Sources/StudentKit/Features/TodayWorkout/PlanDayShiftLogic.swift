import CoreModels
import Foundation
import RepositoryContracts

enum PlanDayShiftOperation: Sendable {
  case shift
  case cancel
}

enum PlanDayShiftLogic {
  static func nextRestDate(
    after date: Date,
    occupiedBy days: [StudentPlanDay],
    planStartDate: Date,
    weekIndex: Int,
    calendar suppliedCalendar: Calendar? = nil
  ) -> Date? {
    let calendar = suppliedCalendar ?? utcCalendar
    let planStart = calendar.startOfDay(for: planStartDate)
    let today = calendar.startOfDay(for: date)
    guard
      let weekStart = calendar.date(
        byAdding: .day,
        value: max(0, weekIndex - 1) * 7,
        to: planStart
      ),
      let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart),
      var candidate = calendar.date(byAdding: .day, value: 1, to: today)
    else { return nil }

    // swiftlint:disable:next todo
    // TODO: Constrain shifts against the meet date once the plan model exposes it.
    while candidate <= weekEnd {
      let occupied = days.contains { calendar.isDate($0.date, inSameDayAs: candidate) }
      if !occupied {
        return candidate
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
        return nil
      }
      candidate = next
    }
    return nil
  }

  static func targetLabel(
    target: Date,
    after date: Date,
    calendar suppliedCalendar: Calendar? = nil
  ) -> String {
    let calendar = suppliedCalendar ?? utcCalendar
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
      calendar.isDate(target, inSameDayAs: tomorrow)
    {
      return "延到明天"
    }
    let targetText = target.formatted(
      .dateTime.month().day().weekday(.short).locale(Locale(identifier: "zh_CN")))
    return "延到\(targetText)"
  }

  static func errorMessage(
    for error: any Error,
    operation: PlanDayShiftOperation
  ) -> String {
    guard let shiftError = error as? PlanDayShiftError else {
      return operation == .shift
        ? "顺延失败，请检查网络后重试"
        : "撤销顺延失败，请检查网络后重试"
    }
    switch shiftError {
    case .planNotActive:
      return "当前计划未生效，暂时不能顺延"
    case .onlyToday:
      return "只能顺延今天的训练；顺延后如需调整，请先撤销"
    case .dayHasLogs:
      return "这天已有训练记录，不能顺延或撤销"
    case .targetNotRestDay:
      return "目标日期已不是本周休息日，请刷新计划后重试"
    case .unavailable:
      return "当前计划暂不支持顺延"
    }
  }

  private static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }
}
