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
          .map(prescribedSet)
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
  private static func prescribedSet(_ planSet: PlanSet) -> PrescribedSet {
    let isRange = planSet.targetRepsMax != nil
    return PrescribedSet(
      id: planSet.id,
      setIndex: planSet.setNumber,
      weightKg: planSet.intensityMode == .weight ? planSet.targetValue : nil,
      reps: isRange ? nil : planSet.targetReps,
      repsMax: planSet.targetRepsMax,
      rpe: planSet.intensityMode == .rpe ? planSet.targetValue : nil
    )
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
