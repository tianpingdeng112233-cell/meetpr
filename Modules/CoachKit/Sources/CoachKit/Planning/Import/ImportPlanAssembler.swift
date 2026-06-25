import CoreModels
import Foundation

// Builds a published entity tree directly from reviewed import state and hands it
// to `PlanRepository.publishPlan` (spec 043 §F). It does NOT go through the draft
// store or `PlanPublishAssembler` (those clone a W1 template + progression rules
// and can't hold hand-tuned multi-week, per-set content).

enum ImportAssemblyError: Error, Equatable, Sendable {
  /// A selected exercise/set failed the completeness gate (§H).
  case incomplete
  /// No weeks were selected.
  case noWeeksSelected
}

struct ImportPlanAssembler {
  var now: @Sendable () -> Date
  var makeID: @Sendable () -> UUID

  init(
    now: @escaping @Sendable () -> Date = { Date() },
    makeID: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.now = now
    self.makeID = makeID
  }

  struct Assembled: Equatable, Sendable {
    let plan: TrainingPlan
    let days: [PlanDay]
    let exercises: [PlanExercise]
    let sets: [PlanSet]
  }

  // swiftlint:disable:next function_body_length
  func assemble(
    traineeID: UUID,
    coachID: UUID?,
    name: String,
    startDate: Date,
    weeks: [ImportReviewWeek]
  ) throws -> Assembled {
    let selected = weeks.filter(\.isSelected)
    guard !selected.isEmpty else { throw ImportAssemblyError.noWeeksSelected }
    guard ImportCompleteness.isPublishable(weeks) else { throw ImportAssemblyError.incomplete }

    let planWeeks = selected.count
    let timestamp = now()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let normalizedStart = calendar.startOfDay(for: startDate)
    let endDate =
      calendar.date(byAdding: .day, value: planWeeks * 7 - 1, to: normalizedStart)
      ?? normalizedStart

    let planID = makeID()
    let plan = TrainingPlan(
      id: planID,
      coachID: coachID,
      traineeID: traineeID,
      name: name,
      startDate: normalizedStart,
      endDate: endDate,
      planWeeks: planWeeks,
      kind: .regular,
      source: .coach,
      sourceTemplateID: nil,
      status: .draft,
      createdAt: timestamp,
      updatedAt: timestamp
    )

    var days: [PlanDay] = []
    var exercises: [PlanExercise] = []
    var sets: [PlanSet] = []
    var sortOrder = 0

    for (weekOffset, week) in selected.enumerated() {
      let weekNumber = weekOffset + 1  // renumber selected weeks 1…N
      for day in week.days where !day.exercises.isEmpty {
        let dayID = makeID()
        days.append(
          PlanDay(
            id: dayID,
            planID: planID,
            dayOfWeek: day.dayOfWeek + 1,  // 0…6 → 1…7
            weekNumber: weekNumber,
            sortOrder: sortOrder
          )
        )
        sortOrder += 1

        for (exerciseIndex, exercise) in day.exercises.enumerated() {
          guard let exerciseID = exercise.boundExerciseID else {
            throw ImportAssemblyError.incomplete
          }
          let planExerciseID = makeID()
          exercises.append(
            PlanExercise(
              id: planExerciseID,
              planDayID: dayID,
              exerciseID: exerciseID,
              isMainLift: exercise.isMainLift,
              sortOrder: exerciseIndex,
              notes: exercise.note
            )
          )

          for set in exercise.sets {
            sets.append(try planSet(set, planExerciseID: planExerciseID, createdAt: timestamp))
          }
        }
      }
    }

    return Assembled(plan: plan, days: days, exercises: exercises, sets: sets)
  }

  /// One reviewed set → one `PlanSet`. Single target, weight-first: a weight
  /// (>0) wins the structured target; otherwise the RPE does.
  private func planSet(
    _ set: ImportReviewSet,
    planExerciseID: UUID,
    createdAt: Date
  ) throws -> PlanSet {
    guard let reps = set.targetReps, reps >= 1 else { throw ImportAssemblyError.incomplete }

    let intensityMode: IntensityMode
    let targetValue: Decimal
    if let weight = set.weightKg, weight > 0 {
      intensityMode = .weight
      targetValue = weight
    } else if let rpe = set.rpe, rpe >= 1, rpe <= 10 {
      intensityMode = .rpe
      targetValue = rpe
    } else {
      throw ImportAssemblyError.incomplete
    }

    return PlanSet(
      id: makeID(),
      planExerciseID: planExerciseID,
      setNumber: set.setNumber,
      targetReps: reps,
      targetRepsMax: set.targetRepsMax,
      intensityMode: intensityMode,
      targetValue: targetValue,
      setType: set.setType,
      restSeconds: nil,
      coachNote: set.coachNote,
      createdAt: createdAt
    )
  }
}
