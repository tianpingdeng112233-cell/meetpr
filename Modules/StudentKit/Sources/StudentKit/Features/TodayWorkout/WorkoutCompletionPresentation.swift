import CoreModels
import Foundation

struct WorkoutCompletionPresentation: Equatable, Sendable {
  struct ExercisePerformance: Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let bestSetText: String
    let isPersonalRecord: Bool
    let completedSetCount: Int
    let failedSetCount: Int

    var statusText: String {
      if failedSetCount > 0 {
        return StudentStrings.replacing(
          .workoutCompletionPresentation001, values: ["\(completedSetCount)", "\(failedSetCount)"])
      }
      return StudentStrings.replacing(
        .workoutCompletionPresentation002, values: ["\(completedSetCount)"])
    }
  }

  let weekCode: String
  let weekDayLabel: String
  let coachReceiptText: String
  let completedSuccessfulSets: Int
  let totalPlannedSets: Int
  let setCompletionLabel: String
  let totalReps: Int
  let mainRPEText: String
  let planComparisonText: String
  let totalVolumeText: String
  let volumeComparisonText: String
  let exerciseCount: Int
  let completedSetCount: Int
  let averageRPEText: String
  let date: Date
  let dateSubtitle: String
  let streak: Int?
  let exercises: [ExercisePerformance]

  var metaText: String {
    StudentStrings.replacing(
      .workoutCompletionPresentation003,
      values: ["\(totalReps)", "\(mainRPEText)", "\(planComparisonText)"])
  }

  var hasPersonalRecord: Bool {
    exercises.contains(where: \.isPersonalRecord)
  }

  var personalRecordText: String {
    let names = exercises.filter(\.isPersonalRecord).map(\.name)
    guard !names.isEmpty else { return "" }
    return StudentStrings.replacing(
      .workoutCompletionPresentation004,
      values: ["\(StudentStrings.listSeparated(names))"]
    )
  }

  init(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    references: [UUID: ExerciseReference],
    weekCode: String,
    coachName: String?,
    streak: Int? = nil,
    previousVolumeChangePercent: Int? = nil,
    locale: Locale = .current
  ) {
    let completed = drafts.filter(\.completed)
    let failedCount = completed.filter(\.failed).count
    let mainExerciseID = day.exercises.first?.id
    let mainSets = completed.filter { $0.planExerciseID == mainExerciseID }
    let mainRPE = Self.average(mainSets.compactMap(Self.resolvedRPE))
    let plannedRPE = drafts.first { $0.planExerciseID == mainExerciseID }?.prescribed.rpe

    self.weekCode = weekCode
    self.weekDayLabel = Self.weekDayLabel(for: weekCode)
    self.coachReceiptText = Self.coachReceiptText(coachName: coachName)
    self.completedSuccessfulSets = completed.count - failedCount
    self.totalPlannedSets = drafts.count
    self.setCompletionLabel =
      failedCount > 0
      ? StudentStrings.replacing(.workoutCompletionPresentation005, values: ["\(failedCount)"])
      : StudentStrings.localized(.workoutCompletionPresentation006)
    self.totalReps = completed.reduce(0) { $0 + Self.resolvedReps($1) }
    self.mainRPEText = mainRPE.map(Self.mainRPEText) ?? "—"
    self.planComparisonText = Self.planComparison(actual: mainRPE, planned: plannedRPE)
    self.totalVolumeText = Self.volumeText(
      completed.reduce(Decimal.zero) { total, draft in
        total + Self.resolvedWeight(draft) * Decimal(Self.resolvedReps(draft))
      }
    )
    self.volumeComparisonText =
      previousVolumeChangePercent.map {
        StudentStrings.replacing(
          .workoutCompletionPresentation007, values: ["\($0 >= 0 ? "+" : "")", "\($0)"])
      } ?? StudentStrings.localized(.workoutCompletionPresentation008)
    self.exerciseCount = day.exercises.count
    self.completedSetCount = completed.count
    self.averageRPEText =
      Self.average(completed.compactMap(Self.resolvedRPE))
      .map(Self.rpeText) ?? "—"
    self.date = day.scheduledDate
    self.dateSubtitle = Self.dateSubtitle(
      date: day.scheduledDate,
      weekCode: weekCode,
      locale: locale
    )
    self.streak = streak
    self.exercises = day.exercises.map { exercise in
      Self.exercisePerformance(
        exercise: exercise,
        drafts: completed.filter { $0.planExerciseID == exercise.id },
        reference: references[exercise.exercise.id]
      )
    }
  }

  private static func exercisePerformance(
    exercise: StudentPlanExercise,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    reference: ExerciseReference?
  ) -> ExercisePerformance {
    let best = drafts.max { lhs, rhs in
      let left = (resolvedWeight(lhs), resolvedReps(lhs))
      let right = (resolvedWeight(rhs), resolvedReps(rhs))
      return left < right
    }
    let isPersonalRecord =
      best.map { draft in
        guard let baseline = reference?.best else { return false }
        let weight = resolvedWeight(draft)
        let baselineWeight = NSDecimalNumber(value: baseline.weightKg).decimalValue
        return weight > baselineWeight
          || (weight == baselineWeight && resolvedReps(draft) > baseline.reps)
      } ?? false

    return ExercisePerformance(
      id: exercise.id,
      name: StudentExerciseName.display(exercise.exercise),
      bestSetText: best.map(Self.bestSetText) ?? "—",
      isPersonalRecord: isPersonalRecord,
      completedSetCount: drafts.count,
      failedSetCount: drafts.filter(\.failed).count
    )
  }

  private static func bestSetText(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    let rpe = resolvedRPE(draft).map(compactDecimal) ?? "—"
    return "\(compactDecimal(resolvedWeight(draft)))kg × \(resolvedReps(draft)) @\(rpe)"
  }

  private static func resolvedWeight(_ draft: TodayWorkoutViewModel.SetRowDraft) -> Decimal {
    draft.actualWeight ?? draft.prescribed.weightKg ?? 0
  }

  private static func resolvedReps(_ draft: TodayWorkoutViewModel.SetRowDraft) -> Int {
    draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0
  }

  private static func resolvedRPE(_ draft: TodayWorkoutViewModel.SetRowDraft) -> Decimal? {
    draft.actualRPE ?? draft.prescribed.rpe
  }

  private static func average(_ values: [Decimal]) -> Decimal? {
    guard !values.isEmpty else { return nil }
    return values.reduce(Decimal.zero, +) / Decimal(values.count)
  }

  private static func planComparison(actual: Decimal?, planned: Decimal?) -> String {
    guard let actual, let planned else {
      return StudentStrings.localized(.workoutCompletionPresentation009)
    }
    let difference = actual - planned
    if abs(NSDecimalNumber(decimal: difference).doubleValue) <= 0.5 {
      return StudentStrings.localized(.workoutCompletionPresentation010)
    }
    return difference > 0
      ? StudentStrings.localized(.workoutCompletionPresentation011)
      : StudentStrings.localized(.workoutCompletionPresentation012)
  }

  private static func compactDecimal(_ value: Decimal) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }

  private static func rpeText(_ value: Decimal) -> String {
    var input = value
    var rounded = Decimal.zero
    NSDecimalRound(&rounded, &input, 1, .plain)
    return rounded.formatted(.number.precision(.fractionLength(1)))
  }

  private static func mainRPEText(_ value: Decimal) -> String {
    // Mockup 1013 judges the raw average: an exactly whole value reads "8";
    // any fractional value keeps one decimal even when it rounds to x.0
    // (8.96 → "9.0"). The four-tile average always uses toFixed(1).
    var input = value
    var whole = Decimal.zero
    NSDecimalRound(&whole, &input, 0, .plain)
    if whole == value {
      return whole.formatted(.number.precision(.fractionLength(0)))
    }
    return rpeText(value)
  }

  private static func volumeText(_ value: Decimal) -> String {
    value.formatted(
      .number
        .grouping(.automatic)
        .precision(.fractionLength(0...2))
        .locale(Locale(identifier: "en_US"))
    )
  }

  private static func weekDayLabel(for weekCode: String) -> String {
    guard
      let dayToken = weekCode.split(separator: "D").last,
      let day = Int(dayToken)
    else { return StudentStrings.localized(.workoutCompletionPresentation013) }
    return StudentStrings.replacing(.workoutCompletionPresentation014, values: ["\(day)"])
  }

  private static func coachReceiptText(coachName: String?) -> String {
    guard let coachName, !coachName.trimmingCharacters(in: .whitespaces).isEmpty else {
      return StudentStrings.localized(.workoutCompletionPresentation015)
    }
    let trimmed = coachName.trimmingCharacters(in: .whitespaces)
    return StudentStrings.replacing(.workoutCompletionPresentation016, values: ["\(trimmed)"])
  }

  private static func dateSubtitle(
    date: Date,
    weekCode: String,
    locale: Locale
  ) -> String {
    let day = StudentFormatting.numericMonthDay(date, locale: locale)
    let weekday = StudentFormatting.weekday(date, locale: locale)
    return "\(day) · \(weekday) · \(weekCode)"
  }
}
