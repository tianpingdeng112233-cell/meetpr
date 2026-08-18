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
      PlanningWorkspaceStrings.text("coach.workspace.need.noCurrentPlan")
    case .ended:
      PlanningWorkspaceStrings.text("coach.workspace.need.ended")
    case .endsThisWeek:
      PlanningWorkspaceStrings.text("coach.workspace.need.endsThisWeek")
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
    return CoachLocalization.localized(
      "coach.workspace.draftSummary \(name) \(stepTitle(step)) \(planWeeks)")
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
    CoachLocalization.localized(
      "coach.workspace.publishedSummary \(planKindTitle(plan.planKind)) \(weeks)")
  }

  static func proxyDateText(
    _ date: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> String {
    let components = calendar.dateComponents([.month, .day], from: date)
    guard let month = components.month, let day = components.day else { return "" }
    return PlanningWorkspaceStrings.replacing(
      "coach.workspace.shortDate", ["month": month, "day": day])
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
    guard let step else { return PlanningWorkspaceStrings.text("coach.workspace.step.notStarted") }
    return switch step {
    case .selectStudent:
      PlanningWorkspaceStrings.text("coach.workspace.step.selectStudent")
    case .selectDuration:
      PlanningWorkspaceStrings.text("coach.workspace.step.selectDuration")
    case .assignFrequency:
      PlanningWorkspaceStrings.text("coach.workspace.step.assignFrequency")
    case .selectMainLifts:
      PlanningWorkspaceStrings.text("coach.workspace.step.selectMainLifts")
    case .selectAccessories:
      PlanningWorkspaceStrings.text("coach.workspace.step.selectAccessories")
    case .fillW1Intensity:
      PlanningWorkspaceStrings.text("coach.workspace.step.fillIntensity")
    case .configureRules:
      PlanningWorkspaceStrings.text("coach.workspace.step.configureRules")
    case .previewWeekCards:
      PlanningWorkspaceStrings.text("coach.workspace.step.preview")
    }
  }

  private static func planKindTitle(_ kind: PlanKind) -> String {
    switch kind {
    case .regular:
      PlanningWorkspaceStrings.text("coach.workspace.kind.regular")
    case .adaptation:
      PlanningWorkspaceStrings.text("coach.workspace.kind.adaptation")
    }
  }
}
