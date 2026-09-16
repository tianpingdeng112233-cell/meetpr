import CoreModels
import Foundation

/// Read-only projection of the selected stored estimate. Current logs supply
/// identity/ordinal only; edited weight or RPE never rewrites its calculation.
struct GrowthE1RMDetail: Identifiable, Equatable, Sendable {
  enum Calculation: Equatable, Sendable {
    case rts(intensity: Double)
    case epley
    case unavailable
  }

  let point: E1RMHistoryPoint
  let exerciseName: String?
  let setNumber: Int?
  let calculation: Calculation

  var id: UUID { point.id }
  var date: Date { point.computedAt }

  init(point: E1RMHistoryPoint, logs: [StudentSetLog], days: [StudentPlanDay]) {
    self.point = point
    let log = logs.first {
      $0.id == point.setLogId && $0.studentID == point.studentId
        && ($0.exerciseID == nil || $0.exerciseID == point.exerciseId)
    }
    let exercise = days.flatMap(\.exercises).first {
      $0.exercise.id == point.exerciseId
        || ($0.id == point.exerciseId && $0.id == log?.planExerciseID)
    }
    self.exerciseName = exercise.map { StudentExerciseName.display($0.exercise) }
    self.setNumber = log.flatMap { $0.setIndex >= 0 ? $0.setIndex + 1 : nil }
    guard point.sourceWeightKg.isFinite, point.e1RMKg.isFinite,
      point.effectiveSourceRPE?.isFinite != false,
      let recalculated = E1RMCalculator.calculate(
        weightKg: point.sourceWeightKg, reps: point.sourceReps, rpe: point.effectiveSourceRPE
      ), recalculated.isFinite, abs(recalculated - point.e1RMKg) < 0.051
    else {
      self.calculation = .unavailable
      return
    }
    if point.effectiveSourceRPE == nil || (point.effectiveSourceRPE ?? 0) < 6 {
      self.calculation = .epley
    } else if let rpe = point.effectiveSourceRPE,
      let intensity = E1RMCalculator.suggestedWeight(
        e1RM: 1, reps: point.sourceReps, rpe: rpe
      )
    {
      self.calculation = .rts(intensity: intensity)
    } else {
      self.calculation = .unavailable
    }
  }
}
