import Foundation

/// Write-protection for the training day (spec 049 §2): writes belong to
/// today. Future days never unlock; past days need an explicit 「补录这一天」
/// step so a mis-tap can't mark tomorrow done or rewrite history.
enum TodayWorkoutDateLock: Equatable, Sendable {
  case editable
  case futureLocked
  case pastLocked
  case pastBackfilling

  static func mode(
    selected: Date,
    today: Date,
    backfillUnlocked: Bool,
    calendar: Calendar = .current
  ) -> TodayWorkoutDateLock {
    let selectedDay = calendar.startOfDay(for: selected)
    let currentDay = calendar.startOfDay(for: today)
    if selectedDay == currentDay { return .editable }
    if selectedDay > currentDay { return .futureLocked }
    return backfillUnlocked ? .pastBackfilling : .pastLocked
  }

  var allowsWrites: Bool {
    self == .editable || self == .pastBackfilling
  }

  var bannerText: String? {
    switch self {
    case .editable: nil
    case .futureLocked: "未来的训练到那天再记"
    case .pastLocked: "这一天已过去,查看为主"
    case .pastBackfilling: "补录模式 · 记录将计入这一天"
    }
  }
}
