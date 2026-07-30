import Foundation

enum CoachWeekOverview {
  struct Week: Hashable, Sendable {
    let dates: [Date]
    let range: ClosedRange<Date>
    let isoWeek: Int
    let todayColumn: Int

    func contains(
      _ date: Date,
      calendar: Calendar = CoachFeatureCalendar.calendar
    ) -> Bool {
      range.contains(CoachFeatureCalendar.startOfDay(date, calendar: calendar))
    }

    func column(
      for date: Date,
      calendar: Calendar = CoachFeatureCalendar.calendar
    ) -> Int? {
      let day = CoachFeatureCalendar.startOfDay(date, calendar: calendar)
      guard contains(day, calendar: calendar), let start = dates.first else { return nil }
      return calendar.dateComponents([.day], from: start, to: day).day
    }
  }

  /// 一个计划训练日 + 可能与它配对的已完成日志时间戳。
  ///
  /// 完成态**不在取数时固化成 Bool**:计划日与日志是否算「同一天」取决于设备日历,
  /// 而设备时区可能在两次取数之间变化。提前压成 Bool 会让聚合时重映射了列、完成态
  /// 却还是旧时区的结论(review-loop 2026-07-30 逮到)。这里保留原始时间戳,由聚合
  /// 现场用同一个 calendar 判定,保证列与完成态永远出自同一份日历。
  struct TrainingDay: Hashable, Sendable {
    let date: Date
    /// 已收窄到本计划日 ±36h 内的完成日志时间戳——足够覆盖任何时区/DST 偏移,
    /// 又不至于把整份日志挂在每一天上。
    let completedLogDates: [Date]

    func isCompleted(calendar: Calendar = CoachFeatureCalendar.calendar) -> Bool {
      completedLogDates.contains {
        CoachFeatureCalendar.isSameDay($0, date, calendar: calendar)
      }
    }
  }

  struct Progress: Hashable, Sendable {
    let completed: Int
    let planned: Int
  }

  enum Group: Hashable, Sendable {
    case active
    case idle
    case attention
  }

  enum Cell: Hashable, Sendable {
    case rest
    case completed
    case missed(isAttention: Bool)
    case upcoming
  }

  struct Legend: Hashable, Identifiable, Sendable {
    let group: Group
    let count: Int

    var id: Group { group }
  }

  struct Row: Hashable, Identifiable, Sendable {
    let studentID: UUID
    let name: String
    let group: Group
    let completed: Int
    let planned: Int
    let cells: [Cell]

    var id: UUID { studentID }
  }

  struct Summary: Hashable, Sendable {
    let completionPercentage: Int
    let completed: Int
    let planned: Int
    let isoWeek: Int
    let todayColumn: Int
    let legend: [Legend]
    let rows: [Row]
  }

  static func makeSummary(
    rows: [StudentRosterRowModel],
    now: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Summary {
    let today = CoachFeatureCalendar.startOfDay(now, calendar: calendar)
    let week = week(containing: today, calendar: calendar)
    let overviewRows = rows.map { row in
      makeRow(row, week: week, today: today, calendar: calendar)
    }
    let completed = overviewRows.reduce(0) { $0 + $1.completed }
    let planned = overviewRows.reduce(0) { $0 + $1.planned }
    let completionPercentage =
      planned > 0
      ? Int((Double(completed) / Double(planned) * 100).rounded())
      : 0
    let groups: [Group] = [.active, .idle, .attention]
    let legend = groups.compactMap { group -> Legend? in
      let count = overviewRows.count { $0.group == group }
      return count > 0 ? Legend(group: group, count: count) : nil
    }

    return Summary(
      completionPercentage: completionPercentage,
      completed: completed,
      planned: planned,
      isoWeek: week.isoWeek,
      todayColumn: week.todayColumn,
      legend: legend,
      rows: overviewRows
    )
  }

  private static func makeRow(
    _ row: StudentRosterRowModel,
    week: Week,
    today: Date,
    calendar: Calendar
  ) -> Row {
    let isAttention = !row.triageSignals.isEmpty
    let weekDays = currentWeekTrainingDays(
      from: row.trainingDays,
      in: week,
      calendar: calendar
    )
    let completed = weekDays.count { $0.isCompleted(calendar: calendar) }
    let group: Group =
      isAttention
      ? .attention
      : completed > 0 ? .active : .idle
    let cells = week.dates.enumerated().map { column, date -> Cell in
      guard
        let plannedDay = weekDays.first(where: {
          week.column(for: $0.date, calendar: calendar) == column
        })
      else {
        return .rest
      }
      if plannedDay.isCompleted(calendar: calendar) {
        return .completed
      }
      if date < today {
        return .missed(isAttention: isAttention)
      }
      return .upcoming
    }

    return Row(
      studentID: row.id,
      name: row.student.displayName,
      group: group,
      completed: completed,
      planned: weekDays.count,
      cells: cells
    )
  }

  static func progress(
    trainingDays: [TrainingDay],
    now: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Progress {
    let week = week(containing: now, calendar: calendar)
    let weekDays = currentWeekTrainingDays(
      from: trainingDays,
      in: week,
      calendar: calendar
    )
    return Progress(
      completed: weekDays.count { $0.isCompleted(calendar: calendar) },
      planned: weekDays.count
    )
  }

  static func week(
    containing date: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Week {
    let today = CoachFeatureCalendar.startOfDay(date, calendar: calendar)
    let start = weekStart(containing: today, calendar: calendar)
    let dates = (0..<7).map { offset in
      calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
    let end = dates.last ?? start
    return Week(
      dates: dates,
      range: start...CoachFeatureCalendar.endOfDay(end, calendar: calendar),
      isoWeek: isoWeekNumber(for: today, calendar: calendar),
      todayColumn: dayOffset(from: start, to: today, calendar: calendar)
    )
  }

  private static func currentWeekTrainingDays(
    from trainingDays: [TrainingDay],
    in week: Week,
    calendar: Calendar
  ) -> [TrainingDay] {
    trainingDays.filter { week.column(for: $0.date, calendar: calendar) != nil }
  }

  private static func weekStart(containing date: Date, calendar: Calendar) -> Date {
    let weekday = calendar.component(.weekday, from: date)
    let daysFromMonday = (weekday + 5) % 7
    return
      calendar.date(byAdding: .day, value: -daysFromMonday, to: date)
      ?? date
  }

  private static func dayOffset(from start: Date, to date: Date, calendar: Calendar) -> Int {
    calendar.dateComponents([.day], from: start, to: date).day ?? 0
  }

  private static func isoWeekNumber(for date: Date, calendar: Calendar) -> Int {
    var isoCalendar = calendar
    isoCalendar.firstWeekday = 2
    isoCalendar.minimumDaysInFirstWeek = 4
    return isoCalendar.component(.weekOfYear, from: date)
  }
}
