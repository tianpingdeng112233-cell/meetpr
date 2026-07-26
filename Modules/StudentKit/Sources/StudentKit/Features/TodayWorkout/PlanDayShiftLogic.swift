import CoreModels
import Foundation
import RepositoryContracts

enum PlanShiftOperation: Sendable {
  case shift
  case cancel
}

struct PlanShiftProposal: Equatable, Sendable {
  let planID: UUID
  let courseName: String
  let currentEndDate: Date
  let shiftedEndDate: Date
}

enum PlanDayShiftLogic {
  static func proposal(
    plan: StudentPlanView,
    today: Date,
    selectedCalendar: Calendar = PlanCalendarDayIdentity.utcCalendar
  ) -> PlanShiftProposal? {
    let calendar = PlanCalendarDayIdentity.utcCalendar
    guard
      // spec 054's mutation (POST /plans/:id/shift, no date parameter) anchors
      // "today" to UTC server-side, so the proposal must resolve the same day
      // the mutation will move. The UI hides the entry point while the device
      // day and UTC day diverge (00:00–08:00 UTC+8) — see
      // `DashboardTodayPresentation.shiftTargetsSelectedDay`.
      let todayDay = plan.days.first(where: {
        PlanCalendarDayIdentity.matches(
          planDate: $0.date,
          selectedDate: today,
          selectedCalendar: selectedCalendar
        )
      }),
      let courseName = todayDay.exercises.first?.exercise.name,
      let authoredEndDate = plan.endDate ?? plan.days.map(\.scheduledDate).max(),
      let currentEndDate = calendar.date(
        byAdding: .day,
        value: plan.totalShiftDays,
        to: authoredEndDate
      ),
      let shiftedEndDate = calendar.date(byAdding: .day, value: 1, to: currentEndDate)
    else { return nil }

    return PlanShiftProposal(
      planID: plan.cycleID,
      courseName: courseName,
      currentEndDate: currentEndDate,
      shiftedEndDate: shiftedEndDate
    )
  }

  static func confirmationMessage(for proposal: PlanShiftProposal) -> String {
    "今天的\(proposal.courseName)课改到明天，之后的课依次顺延，本周期结束日变为"
      + dateText(proposal.shiftedEndDate)
  }

  static func canUndo(
    latestShiftCreatedAt: Date?,
    now: Date
  ) -> Bool {
    guard let latestShiftCreatedAt else { return false }
    return PlanCalendarDayIdentity.isSameUTCDate(latestShiftCreatedAt, now)
  }

  static func cumulativeShiftMessage(totalShiftDays: Int) -> String? {
    guard totalShiftDays >= 3 else { return nil }
    return "已累计顺延 \(totalShiftDays) 天，建议联系教练调整计划"
  }

  static func errorMessage(
    for error: any Error,
    operation: PlanShiftOperation
  ) -> String {
    guard let shiftError = error as? PlanShiftError else {
      return operation == .shift
        ? "顺延失败，请检查网络后重试"
        : "撤销顺延失败，请检查网络后重试"
    }
    switch shiftError {
    case .planNotActive:
      return "当前计划未生效，暂时不能顺延"
    case .onlyToday:
      return "只能顺延今天的训练"
    case .alreadyStarted:
      return "今天的训练已经开始，不能顺延或撤销"
    case .notPlanStudent:
      return "只有计划所属学员可以顺延"
    case .noActiveShift:
      return "当前没有可撤销的顺延"
    case .undoWindowPassed:
      return "只能在顺延当天撤销，请联系教练调整计划"
    case .unavailable:
      return "当前计划暂不支持顺延"
    }
  }

  private static func dateText(_ date: Date) -> String {
    let components = PlanCalendarDayIdentity.utcCalendar.dateComponents(
      [.month, .day],
      from: date
    )
    guard let month = components.month, let day = components.day else { return "" }
    return "\(month)月\(day)日"
  }
}
