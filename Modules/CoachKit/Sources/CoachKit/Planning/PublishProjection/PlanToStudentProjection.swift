import CoreModels
import Foundation

/// Maps the coach's materialized plan tree to the student-facing, read-only
/// projection for a single cycle week.
///
/// Runs on the coach publish path; the student side reads the result without any
/// further mapping. Pure and total — never throws. Days are emitted in
/// chronological order (by `dayOfWeek`), exercises by `sortOrder`, sets by
/// `setNumber`. A `PlanExercise` whose `exerciseID` is absent from `catalog` is
/// dropped, since the student view cannot render an exercise it cannot name.
public enum PlanToStudentProjection {
  private struct Prescription {
    let weightKg: Decimal?
    let intensity: PrescribedIntensity?
    let percentageAnchor: PercentageAnchor?
  }

  // Tree params (plan/days/exercises/sets) mirror PlanRepository.publishPlan;
  // catalog resolves exercise IDs to a full Exercise the student view can render.
  // swiftlint:disable:next function_parameter_count
  public static func project(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet],
    catalog: [Exercise],
    weekIndex: Int
  ) -> StudentPlanView {
    let exerciseByID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    let exercisesByDay = Dictionary(grouping: exercises, by: \.planDayID)
    let setsByExercise = Dictionary(grouping: sets, by: \.planExerciseID)

    let studentDays =
      days
      .filter { $0.weekNumber == weekIndex }
      .sorted(by: chronological)
      .map { day in
        studentDay(
          day,
          startDate: plan.startDate,
          planExercises: exercisesByDay[day.id] ?? [],
          setsByExercise: setsByExercise,
          exerciseByID: exerciseByID
        )
      }

    return StudentPlanView(
      cycleID: plan.id,
      weekIndex: weekIndex,
      startDate: plan.startDate,
      planKind: plan.kind,
      days: studentDays
    )
  }

  private static func chronological(_ lhs: PlanDay, _ rhs: PlanDay) -> Bool {
    if lhs.dayOfWeek == rhs.dayOfWeek { return lhs.sortOrder < rhs.sortOrder }
    return lhs.dayOfWeek < rhs.dayOfWeek
  }

  private static func studentDay(
    _ day: PlanDay,
    startDate: Date,
    planExercises: [PlanExercise],
    setsByExercise: [UUID: [PlanSet]],
    exerciseByID: [UUID: Exercise]
  ) -> StudentPlanDay {
    let exercises =
      planExercises
      .sorted { $0.sortOrder < $1.sortOrder }
      .compactMap { planExercise -> StudentPlanExercise? in
        guard let exercise = exerciseByID[planExercise.exerciseID] else { return nil }
        let prescribed =
          (setsByExercise[planExercise.id] ?? [])
          .sorted { $0.setNumber < $1.setNumber }
          .compactMap(prescribedSet)
        return StudentPlanExercise(
          id: planExercise.id,
          exercise: exercise,
          sequenceIndex: planExercise.sortOrder,
          prescribedSets: prescribed
        )
      }
    return StudentPlanDay(
      id: day.id,
      date: date(for: day, startDate: startDate),
      exercises: exercises
    )
  }

  /// Routes the single `intensityMode` value to the matching field (weight XOR
  /// rpe), and carries reps as either a single value or an upper-bound range.
  /// Returns nil for a corrupt planning row (`setNumber < 1`). Clamping instead would fold
  /// plan sets [0, 1] into execution index [0, 0], and the execution layer keys logs by
  /// (planExerciseID, setIndex) — two cards would silently share one log and the later set
  /// would overwrite the earlier. Dropping the corrupt set keeps every legal set's identity.
  private static func prescribedSet(_ planSet: PlanSet) -> PrescribedSet? {
    guard planSet.setNumber >= 1 else { return nil }
    let prescription = prescription(for: planSet)
    let isRange = planSet.targetRepsMax != nil
    return PrescribedSet(
      id: planSet.id,
      setIndex: planSet.setNumber - 1,
      weightKg: prescription.weightKg,
      intensity: prescription.intensity,
      percentageAnchor: prescription.percentageAnchor,
      loadMode: planSet.loadMode,
      reps: isRange ? nil : planSet.targetReps,
      repsMax: planSet.targetRepsMax,
      restSeconds: restSeconds(for: planSet)
    )
  }

  private static func prescription(
    for planSet: PlanSet
  ) -> Prescription {
    guard let loadMode = planSet.loadMode else {
      return Prescription(
        weightKg: planSet.intensityMode == .weight ? planSet.targetValue : nil,
        intensity: planSet.intensityMode == .rpe ? .rpe(planSet.targetValue) : nil,
        percentageAnchor: nil
      )
    }

    let intensity: PrescribedIntensity?
    switch loadMode {
    case .percentage:
      intensity = planSet.targetPct.map(PrescribedIntensity.percentage)
    case .rpe:
      intensity = planSet.targetRPE.map(PrescribedIntensity.rpe)
    case .rir:
      intensity = planSet.rirTarget.map(PrescribedIntensity.rir)
    case .rpeRange:
      intensity = range(planSet.rpeLow, planSet.rpeHigh).map {
        PrescribedIntensity.rpeRange($0.0, $0.1)
      }
    case .weightRange:
      intensity = range(planSet.weightLow, planSet.weightHigh).map {
        PrescribedIntensity.weightRange($0.0, $0.1)
      }
    case .fixedWeight:
      intensity = nil
    }
    let percentageAnchor =
      loadMode == .percentage ? planSet.percentageAnchor ?? .registeredOneRM : nil
    return Prescription(
      weightKg: planSet.targetWeight,
      intensity: intensity,
      percentageAnchor: percentageAnchor
    )
  }

  private static func range(
    _ low: Decimal?, _ high: Decimal?
  ) -> ((Decimal, Decimal))? {
    guard let low, let high else { return nil }
    return (low, high)
  }

  private static func restSeconds(for planSet: PlanSet) -> Int? {
    guard planSet.restSeconds == nil, let loadMode = planSet.loadMode else {
      return planSet.restSeconds
    }
    let rpe: Decimal?
    switch loadMode {
    case .rpe:
      rpe = planSet.targetRPE
    case .rpeRange:
      rpe = planSet.rpeLow
    case .percentage, .rir, .weightRange, .fixedWeight:
      rpe = nil
    }
    return RestDefaults.seconds(forRPE: rpe)
  }

  /// The plan stores only `(weekNumber, dayOfWeek)`; the student view needs a real
  /// date, anchored at `startDate` (cycle week 1, dayOfWeek 1). A fixed UTC
  /// calendar keeps the result deterministic regardless of machine timezone.
  private static func date(for day: PlanDay, startDate: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let offset = (day.weekNumber - 1) * 7 + (day.dayOfWeek - 1)
    return calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
  }
}
