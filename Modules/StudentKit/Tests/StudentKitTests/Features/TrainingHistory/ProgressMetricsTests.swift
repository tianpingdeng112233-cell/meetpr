import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func weeklyMetricsSumCompletedVolumeAcrossMultipleWeeks() {
  let calendar = fixedCalendar()
  let logs = [
    makeLog(date: date(2026, 6, 1, calendar: calendar), weight: "100.5", reps: 5),
    makeLog(date: date(2026, 6, 3, calendar: calendar), weight: "80", reps: 3),
    makeLog(date: date(2026, 6, 8, calendar: calendar), weight: "110", reps: 5),
    makeLog(date: date(2026, 6, 15, calendar: calendar), weight: "120", reps: 2),
  ]

  let buckets = ProgressMetrics.weeklyVolumeIntensity(from: logs, calendar: calendar)

  #expect(
    buckets.map(\.weekStart) == [
      startOfDay(2026, 6, 1, calendar: calendar),
      startOfDay(2026, 6, 8, calendar: calendar),
      startOfDay(2026, 6, 15, calendar: calendar),
    ])
  #expect(
    buckets.map(\.volumeKg) == [
      decimal("742.5"),
      decimal("550"),
      decimal("240"),
    ])
}

@Test func weeklyMetricsAverageRPEExcludesMissingAndIncompleteSets() {
  let calendar = fixedCalendar()
  let logs = [
    makeLog(
      date: date(2026, 6, 1, calendar: calendar),
      weight: "100",
      reps: 5,
      rpe: "7.5"
    ),
    makeLog(date: date(2026, 6, 2, calendar: calendar), weight: "80", reps: 5, rpe: nil),
    makeLog(
      date: date(2026, 6, 3, calendar: calendar),
      weight: "200",
      reps: 1,
      rpe: "10",
      completed: false
    ),
    makeLog(
      date: date(2026, 6, 4, calendar: calendar),
      weight: "60",
      reps: 10,
      rpe: "8.5"
    ),
  ]

  let buckets = ProgressMetrics.weeklyVolumeIntensity(from: logs, calendar: calendar)

  #expect(buckets.map(\.volumeKg) == [decimal("1500")])
  let averageRPE = buckets.first?.avgRPE ?? -1
  #expect(abs(averageRPE - 8.0) < 0.0001)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func emptyMetricsReturnEmptyAndChartCanInitialize() {
  let buckets = ProgressMetrics.weeklyVolumeIntensity(from: [], calendar: fixedCalendar())

  #expect(buckets.isEmpty)
  _ = VolumeIntensityChart(buckets: buckets)
}

private func fixedCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.locale = Locale(identifier: "en_US_POSIX")
  calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
  calendar.firstWeekday = 2
  calendar.minimumDaysInFirstWeek = 4
  return calendar
}

private func makeLog(
  date: Date,
  weight: String,
  reps: Int,
  rpe: String? = "8",
  completed: Bool = true
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: StudentDemoSeed.studentID,
    planExerciseID: UUID(),
    setIndex: 0,
    loggedAt: date,
    weightKg: decimal(weight),
    reps: reps,
    rpe: rpe.map(decimal),
    completed: completed
  )
}

private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
  var components = DateComponents()
  components.calendar = calendar
  components.timeZone = calendar.timeZone
  components.year = year
  components.month = month
  components.day = day
  components.hour = 12
  return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

private func startOfDay(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
  calendar.startOfDay(for: date(year, month, day, calendar: calendar))
}

private func decimal(_ value: String) -> Decimal {
  Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
}
