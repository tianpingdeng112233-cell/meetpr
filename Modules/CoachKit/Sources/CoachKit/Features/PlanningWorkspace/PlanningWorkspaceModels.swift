import CoreModels
import Foundation

struct PlanningDraftRowModel: Identifiable, Equatable, Sendable {
  let student: CoachStudentSummary
  let summary: String
  let lastSavedAt: Date

  var id: UUID { student.id }
}

struct PlanningNeededRowModel: Identifiable, Equatable, Sendable {
  let student: CoachStudentSummary
  let reason: PlanningPlanNeedReason
  let summary: String
  let profile: OnboardingProfile?

  var id: UUID { student.id }
}

struct PlanningPublishedRowModel: Identifiable, Equatable, Sendable {
  let student: CoachStudentSummary
  let summary: String
  let proxyPublishedAt: Date

  var id: UUID { student.id }
}

enum PlanningPlanNeedReason: Equatable, Sendable {
  case noCurrentPlan
  case ended
  case endsThisWeek

  var title: String {
    switch self {
    case .noCurrentPlan:
      "暂无在跑计划"
    case .ended:
      "计划已结束"
    case .endsThisWeek:
      "计划本周内结束"
    }
  }
}

enum PlanningWorkspaceSummary {
  static func draftProgressSummary(
    name: String,
    currentStepRawValue: Int,
    planWeeks: Int
  ) -> String {
    let step = PlanningStep(rawValue: currentStepRawValue)
    return "\(name) · \(stepTitle(step)) · \(planWeeks)周"
  }

  static func planNeedReason(
    plan: StudentPlanView?,
    cycleDays: [StudentPlanDay],
    now: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> PlanningPlanNeedReason? {
    guard plan != nil else { return .noCurrentPlan }
    guard let cycleEnd = cycleEndDate(from: cycleDays, calendar: calendar) else { return nil }

    let today = CoachFeatureCalendar.startOfDay(now, calendar: calendar)
    if cycleEnd < today {
      return .ended
    }

    let threshold =
      calendar.date(byAdding: .day, value: 6, to: today)
      ?? today
    let weekEnd = CoachFeatureCalendar.endOfDay(threshold, calendar: calendar)
    return cycleEnd <= weekEnd ? .endsThisWeek : nil
  }

  static func cycleWeekCount(
    cycleDays: [StudentPlanDay],
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Int? {
    let anchors = cycleDayAnchors(cycleDays, calendar: calendar)
    guard let first = anchors.min(), let last = anchors.max() else { return nil }
    let daySpan = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
    return max(1, (daySpan + 6) / 7)
  }

  static func publishedSummary(plan: StudentPlanView, weeks: Int) -> String {
    "\(planKindTitle(plan.planKind)) · \(weeks)周"
  }

  static func proxyDateText(
    _ date: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> String {
    let components = calendar.dateComponents([.month, .day], from: date)
    guard let month = components.month, let day = components.day else { return "" }
    return "\(month)月\(day)日"
  }

  private static func cycleEndDate(
    from cycleDays: [StudentPlanDay],
    calendar: Calendar
  ) -> Date? {
    cycleDayAnchors(cycleDays, calendar: calendar).max()
  }

  private static func cycleDayAnchors(
    _ cycleDays: [StudentPlanDay],
    calendar: Calendar
  ) -> [Date] {
    cycleDays.map { CoachFeatureCalendar.startOfDay($0.date, calendar: calendar) }
  }

  private static func stepTitle(_ step: PlanningStep?) -> String {
    guard let step else { return "未开始" }
    return switch step {
    case .selectStudent:
      "选学员"
    case .selectDuration:
      "选周期"
    case .assignFrequency:
      "分配频率"
    case .selectMainLifts:
      "选主项"
    case .selectAccessories:
      "选辅助"
    case .fillW1Intensity:
      "填强度"
    case .configureRules:
      "配置进阶"
    case .previewWeekCards:
      "预览发布"
    }
  }

  private static func planKindTitle(_ kind: PlanKind) -> String {
    switch kind {
    case .regular:
      "正式计划"
    case .adaptation:
      "适应周"
    }
  }
}
