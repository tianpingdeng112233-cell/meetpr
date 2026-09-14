import CoreModels
import Foundation

struct QuickLogPlan: Equatable, Sendable {
  struct Entry: Sendable {
    let draft: TodayWorkoutViewModel.SetRowDraft
    let log: StudentSetLog
  }

  struct Row: Equatable, Sendable, Identifiable {
    let id: UUID
    var draft: TodayWorkoutViewModel.SetRowDraft
    var included: Bool
    var usesAutomaticWeight: Bool

    init(
      draft: TodayWorkoutViewModel.SetRowDraft,
      included: Bool = true,
      usesAutomaticWeight: Bool = false
    ) {
      self.id = draft.id
      self.draft = draft
      self.included = included
      self.usesAutomaticWeight = usesAutomaticWeight
    }
  }

  private(set) var rows: [Row]
  private(set) var selectedDate: Date
  let allowedDateRange: ClosedRange<Date>
  let calendar: Calendar

  init(
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    selectedDate: Date,
    allowedDateRange: ClosedRange<Date>,
    calendar: Calendar,
    automaticWeightRowIDs: Set<UUID> = []
  ) {
    self.calendar = calendar
    let upperBound = calendar.startOfDay(for: allowedDateRange.upperBound)
    let requestedLowerBound = calendar.startOfDay(for: allowedDateRange.lowerBound)
    let lowerBound = min(requestedLowerBound, upperBound)
    self.allowedDateRange = lowerBound...upperBound
    self.selectedDate = Self.clampedDay(
      selectedDate,
      to: lowerBound...upperBound,
      calendar: calendar
    )
    self.rows = drafts.map {
      Row(draft: $0, usesAutomaticWeight: automaticWeightRowIDs.contains($0.id))
    }
  }

  var includedSetCount: Int {
    rows.count(where: \.included)
  }

  var includedExerciseCount: Int {
    Set(rows.filter(\.included).map(\.draft.planExerciseID)).count
  }

  var hasIncludedSets: Bool {
    includedSetCount > 0
  }

  var loggedAt: Date {
    let day = calendar.dateComponents([.year, .month, .day], from: selectedDate)
    var components = day
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.hour = 12
    return calendar.date(from: components) ?? selectedDate
  }

  var loggedDate: String {
    let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
    return [
      Self.padded(components.year ?? 0, width: 4),
      Self.padded(components.month ?? 0, width: 2),
      Self.padded(components.day ?? 0, width: 2),
    ].joined(separator: "-")
  }

  mutating func selectDate(_ date: Date) {
    selectedDate = Self.clampedDay(date, to: allowedDateRange, calendar: calendar)
  }

  mutating func updateWeight(_ weight: Decimal?, for rowID: UUID) {
    update(rowID) {
      $0.draft.actualWeight = weight
      $0.usesAutomaticWeight = false
    }
  }

  mutating func updateReps(_ reps: Int?, for rowID: UUID) {
    update(rowID) { $0.draft.actualReps = reps }
  }

  mutating func updateRPE(_ rpe: Decimal?, for rowID: UUID) {
    update(rowID) { $0.draft.actualRPE = rpe }
  }

  mutating func setIncluded(_ included: Bool, for rowID: UUID) {
    update(rowID) { $0.included = included }
  }

  mutating func setExerciseIncluded(_ included: Bool, planExerciseID: UUID) {
    for index in rows.indices where rows[index].draft.planExerciseID == planExerciseID {
      rows[index].included = included
    }
  }

  mutating func syncWeightToExercise(from rowID: UUID) {
    guard let source = rows.first(where: { $0.id == rowID }) else { return }
    let planExerciseID = source.draft.planExerciseID
    for index in rows.indices where rows[index].draft.planExerciseID == planExerciseID {
      rows[index].draft.actualWeight = source.draft.actualWeight
      rows[index].usesAutomaticWeight = false
    }
  }

  func makeLogs(studentID: UUID) -> [StudentSetLog] {
    entries(studentID: studentID).map(\.log)
  }

  func entries(studentID: UUID) -> [Entry] {
    rows.filter(\.included).map {
      let log =
        TodayWorkoutViewModel.makeLog(
          from: $0.draft,
          studentID: studentID,
          completed: true,
          failed: false,
          loggedAt: loggedAt,
          loggedDate: loggedDate
        )
      return Entry(draft: $0.draft, log: log)
    }
  }

  private mutating func update(_ rowID: UUID, mutation: (inout Row) -> Void) {
    guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
    mutation(&rows[index])
  }

  private static func clampedDay(
    _ date: Date,
    to range: ClosedRange<Date>,
    calendar: Calendar
  ) -> Date {
    min(max(calendar.startOfDay(for: date), range.lowerBound), range.upperBound)
  }

  private static func padded(_ value: Int, width: Int) -> String {
    let value = String(value)
    return String(repeating: "0", count: max(0, width - value.count)) + value
  }
}
