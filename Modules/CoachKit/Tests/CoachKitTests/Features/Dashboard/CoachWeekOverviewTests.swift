import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Suite("Coach week overview")
struct CoachWeekOverviewTests {
  @Test("an empty current week never falls back to whole-plan totals")
  func emptyWeekDoesNotUsePlanTotals() throws {
    let calendar = try calendar(timeZoneID: "Asia/Shanghai")
    let now = try date(2026, 7, 29, hour: 12, calendar: calendar)
    let priorPlanDay = try date(2026, 7, 15, hour: 12, calendar: calendar)
    let rosterRow = row(
      name: "休息周",
      days: [trainingDay(date: priorPlanDay, completed: true)]
    )

    let progress = CoachWeekOverview.progress(
      trainingDays: rosterRow.trainingDays,
      now: now,
      calendar: calendar
    )
    let summary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: now,
      calendar: calendar
    )
    let summaryRow = try #require(summary.rows.first)

    #expect(progress == CoachWeekOverview.Progress(completed: 0, planned: 0))
    #expect(summary.completed == 0)
    #expect(summary.planned == 0)
    #expect(summaryRow.completed == 0)
    #expect(summaryRow.planned == 0)
    #expect(summaryRow.cells == Array(repeating: .rest, count: 7))
  }

  @Test("current-week training days produce the expected progress and cells")
  func currentWeekProgress() throws {
    let calendar = try calendar(timeZoneID: "Asia/Shanghai")
    let monday = try date(2026, 7, 27, hour: 12, calendar: calendar)
    let wednesday = try shifted(monday, by: 2, calendar: calendar)
    let rosterRow = row(
      name: "本周有计划",
      days: [
        trainingDay(date: monday, completed: true),
        trainingDay(date: wednesday, completed: false),
      ]
    )

    let progress = CoachWeekOverview.progress(
      trainingDays: rosterRow.trainingDays,
      now: wednesday,
      calendar: calendar
    )
    let summary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: wednesday,
      calendar: calendar
    )
    let summaryRow = try #require(summary.rows.first)

    #expect(progress == CoachWeekOverview.Progress(completed: 1, planned: 2))
    #expect(summaryRow.completed == 1)
    #expect(summaryRow.planned == 2)
    #expect(summaryRow.cells[0] == .completed)
    #expect(summaryRow.cells[1] == .rest)
    #expect(summaryRow.cells[2] == .upcoming)
  }

  @Test("aggregates real plan dates into Monday through Sunday cells")
  // swiftlint:disable:next function_body_length
  func aggregatesPlanDates() throws {
    let calendar = try calendar(timeZoneID: "Asia/Shanghai")
    let monday = try date(2026, 7, 27, hour: 12, calendar: calendar)
    let now = try shifted(monday, by: 2, calendar: calendar)
    let activeID = UUID()
    let attentionID = UUID()
    let idleID = UUID()
    let rows = [
      row(
        id: activeID,
        name: "在练",
        signals: [],
        days: [
          trainingDay(date: monday, completed: true),
          trainingDay(date: now, completed: false),
        ]
      ),
      row(
        id: attentionID,
        name: "待关注",
        signals: [.notTrained(daysMissed: 2)],
        days: [
          trainingDay(date: try shifted(monday, by: 1, calendar: calendar), completed: false),
          trainingDay(date: try shifted(monday, by: 4, calendar: calendar), completed: false),
        ]
      ),
      row(
        id: idleID,
        name: "未开始",
        signals: [],
        days: [
          trainingDay(date: try shifted(monday, by: 5, calendar: calendar), completed: false)
        ]
      ),
    ]

    let summary = CoachWeekOverview.makeSummary(rows: rows, now: now, calendar: calendar)

    #expect(summary.completed == 1)
    #expect(summary.planned == 5)
    #expect(summary.completionPercentage == 20)
    #expect(summary.isoWeek == 31)
    #expect(summary.todayColumn == 2)
    #expect(summary.legend.map(\.group) == [.active, .idle, .attention])
    #expect(summary.legend.map(\.count) == [1, 1, 1])

    let active = try #require(summary.rows.first { $0.studentID == activeID })
    #expect(active.group == .active)
    #expect(active.cells[0] == .completed)
    #expect(active.cells[1] == .rest)
    #expect(active.cells[2] == .upcoming)

    let attention = try #require(summary.rows.first { $0.studentID == attentionID })
    #expect(attention.group == .attention)
    #expect(attention.cells[1] == .missed(isAttention: true))
    #expect(attention.cells[4] == .upcoming)

    let idle = try #require(summary.rows.first { $0.studentID == idleID })
    #expect(idle.group == .idle)
  }

  @Test("the same retained dates remap when Sunday rolls into Monday")
  func remapsAcrossWeekBoundary() throws {
    let calendar = try calendar(timeZoneID: "Asia/Shanghai")
    let sunday = try date(2026, 8, 2, hour: 12, calendar: calendar)
    let monday = try shifted(sunday, by: 1, calendar: calendar)
    let rosterRow = row(
      days: [
        trainingDay(date: sunday, completed: true),
        trainingDay(date: monday, completed: false),
      ]
    )

    let sundaySummary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: sunday,
      calendar: calendar
    )
    let mondaySummary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: monday,
      calendar: calendar
    )
    let sundayRow = try #require(sundaySummary.rows.first)
    let mondayRow = try #require(mondaySummary.rows.first)

    #expect(sundaySummary.todayColumn == 6)
    #expect(sundayRow.planned == 1)
    #expect(sundayRow.cells[6] == .completed)
    #expect(mondaySummary.todayColumn == 0)
    #expect(mondayRow.planned == 1)
    #expect(mondayRow.cells[0] == .upcoming)
    #expect(mondayRow.cells[6] == .rest)
  }

  @Test("ISO week and columns stay correct across a calendar-year boundary")
  func mapsAcrossISOYearBoundary() throws {
    let calendar = try calendar(timeZoneID: "Asia/Shanghai")
    let wednesday = try date(2025, 12, 31, hour: 12, calendar: calendar)
    let thursday = try shifted(wednesday, by: 1, calendar: calendar)
    let rosterRow = row(
      days: [
        trainingDay(date: wednesday, completed: true),
        trainingDay(date: thursday, completed: false),
      ]
    )

    let summary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: thursday,
      calendar: calendar
    )
    let summaryRow = try #require(summary.rows.first)

    #expect(summary.isoWeek == 1)
    #expect(summary.todayColumn == 3)
    #expect(summaryRow.cells[2] == .completed)
    #expect(summaryRow.cells[3] == .upcoming)
  }

  @Test("column mapping uses the supplied positive or negative time zone")
  func remapsAcrossTimeZones() throws {
    let shanghai = try calendar(timeZoneID: "Asia/Shanghai")
    let losAngeles = try calendar(timeZoneID: "America/Los_Angeles")
    let instant = Date(timeIntervalSince1970: 1_767_199_800)
    let rosterRow = row(days: [trainingDay(date: instant, completed: true)])

    let shanghaiSummary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: instant,
      calendar: shanghai
    )
    let losAngelesSummary = CoachWeekOverview.makeSummary(
      rows: [rosterRow],
      now: instant,
      calendar: losAngeles
    )
    let shanghaiRow = try #require(shanghaiSummary.rows.first)
    let losAngelesRow = try #require(losAngelesSummary.rows.first)

    #expect(shanghaiSummary.todayColumn == 3)
    #expect(shanghaiRow.cells[3] == .completed)
    #expect(losAngelesSummary.todayColumn == 2)
    #expect(losAngelesRow.cells[2] == .completed)
  }

  private func row(
    id: UUID = UUID(),
    name: String = "学员",
    signals: [TriageSignal] = [],
    days: [CoachWeekOverview.TrainingDay]
  ) -> StudentRosterRowModel {
    StudentRosterRowModel(
      student: CoachStudentSummary(id: id, displayName: name, status: .active),
      lastActiveAt: nil,
      triageSignals: signals,
      trainingDays: days
    )
  }

  /// `completed: true` 造一条**与计划日同一时刻**的完成日志——完成态由聚合现场
  /// 按 calendar 判定,不再直接塞 Bool(否则时区用例是假绿:列会重映射而完成态不会)。
  private func trainingDay(
    date: Date,
    completed: Bool
  ) -> CoachWeekOverview.TrainingDay {
    CoachWeekOverview.TrainingDay(
      date: date,
      completedLogDates: completed ? [date] : []
    )
  }

  private func calendar(timeZoneID: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
    return calendar
  }

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int,
    calendar: Calendar
  ) throws -> Date {
    try #require(
      calendar.date(
        from: DateComponents(
          year: year,
          month: month,
          day: day,
          hour: hour
        )
      )
    )
  }

  private func shifted(
    _ date: Date,
    by days: Int,
    calendar: Calendar
  ) throws -> Date {
    try #require(calendar.date(byAdding: .day, value: days, to: date))
  }
}
