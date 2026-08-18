import CoreModels
import Foundation

enum PlanningDisplay {
  static func liftName(_ family: LiftFamily) -> String {
    switch family {
    case .squat:
      CoachPlanningStrings.squat
    case .bench:
      CoachPlanningStrings.benchPress
    case .deadlift:
      CoachPlanningStrings.deadlift
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  static func muscleGroupName(_ muscleGroup: MuscleGroup) -> String {
    switch muscleGroup {
    case .chest:
      CoachPlanningStrings.chest
    case .shoulder:
      CoachPlanningStrings.shoulder
    case .back:
      CoachPlanningStrings.back
    case .biceps:
      CoachPlanningStrings.biceps
    case .triceps:
      CoachPlanningStrings.triceps
    case .forearm:
      CoachPlanningStrings.forearm
    case .core:
      CoachPlanningStrings.core
    case .quad:
      CoachPlanningStrings.quadriceps
    case .hamstring:
      CoachPlanningStrings.hamstrings
    case .glute:
      CoachPlanningStrings.glutes
    case .hip, .hipFlexor:
      CoachPlanningStrings.hip
    case .adductor:
      CoachPlanningStrings.adductors
    case .calf:
      CoachPlanningStrings.calves
    case .tibialis, .trap, .mobility, .cardio, .grip:
      CoachPlanningStrings.other
    }
  }

  /// Deduplicates muscle group display names so an exercise tagged with e.g.
  /// `[trap, grip]` doesn't render as "其他 + 其他".
  static func deduplicatedMuscleGroupNames(_ muscleGroups: [MuscleGroup]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for muscleGroup in muscleGroups {
      let name = muscleGroupName(muscleGroup)
      if seen.insert(name).inserted {
        result.append(name)
      }
    }
    return result
  }

  static func equipmentName(_ equipment: Equipment) -> String {
    switch equipment {
    case .barbell:
      CoachPlanningStrings.barbell
    case .dumbbell:
      CoachPlanningStrings.dumbbell
    case .machine:
      CoachPlanningStrings.machine
    case .bodyweight:
      CoachPlanningStrings.bodyweight
    case .cable:
      CoachPlanningStrings.cable
    case .band:
      CoachPlanningStrings.resistanceBand
    case .kettlebell:
      CoachPlanningStrings.kettlebell
    case .specialtyBar:
      CoachPlanningStrings.specialtyBar
    case .other:
      CoachPlanningStrings.other
    }
  }

  static func movementPatternName(_ movementPattern: MovementPattern) -> String {
    switch movementPattern {
    case .squat:
      CoachPlanningStrings.squatPattern
    case .horizontalPush:
      CoachPlanningStrings.horizontalPush
    case .verticalPush:
      CoachPlanningStrings.verticalPush
    case .hipHinge:
      CoachPlanningStrings.hipHinge
    case .horizontalPull:
      CoachPlanningStrings.horizontalPull
    case .verticalPull:
      CoachPlanningStrings.verticalPull
    case .other:
      CoachPlanningStrings.other
    case .warmUp:
      CoachPlanningStrings.warmUp
    }
  }

  static func facetSummary(for exercise: Exercise) -> String {
    let muscleGroups = deduplicatedMuscleGroupNames(exercise.muscleGroups).joined(separator: " + ")
    let equipment = exercise.equipment.map(equipmentName).joined(separator: " + ")
    let movementPattern = exercise.movementPattern.map(movementPatternName).joined(separator: " + ")
    return [muscleGroups, equipment, movementPattern]
      .filter { !$0.isEmpty }
      .joined(separator: " / ")
  }

  static func abnormalReason(_ reason: AbnormalReason) -> String {
    switch reason {
    case .noTrainingForDays(let days):
      CoachPlanningStrings.daysNotTrained(days)
    case .stuckOnWeek(let week):
      CoachPlanningStrings.stuckOnWeek(week)
    }
  }
}
