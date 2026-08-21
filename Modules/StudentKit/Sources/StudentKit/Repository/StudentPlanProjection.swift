import CoreModels
import Foundation
import Networking

/// `internal` so unit tests can exercise the backend projection directly.
enum StudentPlanProjection {
  private struct Prescription {
    let weightKg: Decimal?
    let intensity: PrescribedIntensity?
    let percentageAnchor: PercentageAnchor?
  }

  static func project(
    tree: TrainingPlanTree,
    catalog: [Exercise],
    weekIndex: Int
  ) -> StudentPlanView {
    let exerciseByID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    let exercisesByDay = Dictionary(grouping: tree.exercises, by: \.planDayID)
    let setsByExercise = Dictionary(grouping: tree.sets, by: \.planExerciseID)
    let firstScheduledDate = alignedStartDate(
      tree.plan.startDate,
      anchorWeekday: tree.plan.anchorWeekday
    )
    let days =
      tree.days.map { day in
        studentDay(
          day,
          firstScheduledDate: firstScheduledDate,
          planExercises: exercisesByDay[day.id] ?? [],
          setsByExercise: setsByExercise,
          exerciseByID: exerciseByID
        )
      }
      .sorted(by: StudentPlanSequence.precedes)

    return StudentPlanView(
      cycleID: tree.plan.id,
      weekIndex: days.first(where: { $0.completedAt == nil })?.weekNumber
        ?? days.last?.weekNumber
        ?? weekIndex,
      startDate: tree.plan.startDate,
      endDate: tree.plan.endDate,
      planKind: tree.plan.kind,
      publishedAt: tree.plan.publishedAt,
      totalShiftDays: tree.plan.totalShiftDays,
      latestShiftCreatedAt: tree.plan.latestShiftCreatedAt,
      days: days
    )
  }

  private static func studentDay(
    _ day: PlanDay,
    firstScheduledDate: Date,
    planExercises: [PlanExercise],
    setsByExercise: [UUID: [PlanSet]],
    exerciseByID: [UUID: Exercise]
  ) -> StudentPlanDay {
    let exercises =
      planExercises
      .sorted { $0.sortOrder < $1.sortOrder }
      .compactMap { planExercise -> StudentPlanExercise? in
        guard let exercise = exerciseByID[planExercise.exerciseID] else { return nil }
        return StudentPlanExercise(
          id: planExercise.id,
          exercise: exercise,
          sequenceIndex: planExercise.sortOrder,
          prescribedSets: (setsByExercise[planExercise.id] ?? [])
            .sorted { $0.setNumber < $1.setNumber }
            .compactMap(prescribedSet),
          notes: planExercise.notes
        )
      }
    return StudentPlanDay(
      id: day.id,
      weekNumber: day.weekNumber,
      dayOfWeek: day.dayOfWeek,
      sortOrder: day.sortOrder,
      date: scheduledDate(for: day, firstScheduledDate: firstScheduledDate),
      shiftedToDate: day.shiftedToDate,
      completedAt: day.completedAt,
      completionSource: day.completionSource,
      exercises: exercises
    )
  }

  /// Drops corrupt one-based set numbers instead of aliasing a legal set's log identity.
  private static func prescribedSet(_ planSet: PlanSet) -> PrescribedSet? {
    guard planSet.setNumber >= 1 else { return nil }
    let prescription = prescription(for: planSet)
    return PrescribedSet(
      id: planSet.id,
      setIndex: planSet.setNumber - 1,
      weightKg: prescription.weightKg,
      intensity: prescription.intensity,
      percentageAnchor: prescription.percentageAnchor,
      loadMode: planSet.loadMode,
      reps: planSet.targetReps,
      repsMax: planSet.targetRepsMax,
      restSeconds: restSeconds(for: planSet),
      coachNote: planSet.coachNote
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

  static func scheduledDate(
    for day: PlanDay,
    startDate: Date,
    anchorWeekday: Int?
  ) -> Date {
    scheduledDate(
      for: day,
      firstScheduledDate: alignedStartDate(startDate, anchorWeekday: anchorWeekday)
    )
  }

  private static func alignedStartDate(_ startDate: Date, anchorWeekday: Int?) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    guard let anchorWeekday, (1...7).contains(anchorWeekday) else { return startDate }
    let calendarWeekday = calendar.component(.weekday, from: startDate)
    let startISOWeekday = ((calendarWeekday + 5) % 7) + 1
    let anchorOffset = (anchorWeekday - startISOWeekday + 7) % 7
    return calendar.date(byAdding: .day, value: anchorOffset, to: startDate) ?? startDate
  }

  private static func scheduledDate(for day: PlanDay, firstScheduledDate: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let offset = (day.weekNumber - 1) * 7 + (day.dayOfWeek - 1)
    return calendar.date(byAdding: .day, value: offset, to: firstScheduledDate)
      ?? firstScheduledDate
  }
}
