import CoreModels
import Foundation

/// Revalues stored source sets without replaying eligibility, PRs, or baselines.
actor E1RMExtendedRPETableMigration {
  private let e1rm: LocalE1RMRepository
  private let marker: any E1RMMigrationStoring

  init(
    e1rm: LocalE1RMRepository,
    marker: any E1RMMigrationStoring = UserDefaultsE1RMMigrationStore(
      version: "e1rm-extended-rpe-table-v1")
  ) {
    self.e1rm = e1rm
    self.marker = marker
  }

  func runIfNeeded(studentID: UUID) async throws {
    guard !(await marker.isCompleted(studentID: studentID)) else { return }
    try Task.checkCancellation()
    try await e1rm.recalculateExtendedRPEHistory(studentID: studentID)
    try Task.checkCancellation()
    await marker.markCompleted(studentID: studentID)
  }
}

extension E1RMHistoryPoint {
  func recalculatedWithExtendedRPETable() -> E1RMHistoryPoint {
    guard
      let rpe = effectiveSourceRPE, (6...10).contains(rpe),
      let value = E1RMCalculator.calculate(
        weightKg: sourceWeightKg, reps: sourceReps, rpe: rpe)
    else { return self }
    return E1RMHistoryPoint(
      id: id, studentId: studentId, exerciseId: exerciseId,
      family: family, setLogId: setLogId, computedAt: computedAt,
      e1RMKg: value, sourceWeightKg: sourceWeightKg, sourceReps: sourceReps,
      sourceRPE: sourceRPE, sourceCoachRPE: sourceCoachRPE,
      confidence: confidence, origin: origin)
  }
}
