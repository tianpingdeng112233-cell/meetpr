import CoreModels

/// The single eligibility gate for sets entering e1RM estimation and PR
/// detection (spec 050 §1). Ineligible sets still remain in the training log.
enum E1RMEligibility {
  /// `nil` RPE remains eligible because coached plans often have no measured
  /// RPE. Deadlifts use a tighter rep ceiling because grip and position
  /// fatigue make high-rep estimates systematically unreliable.
  static func isEligible(
    completed: Bool = true,
    failed: Bool = false,
    reps: Int,
    rpe: Double?,
    family: LiftFamily?
  ) -> Bool {
    guard completed, !failed else { return false }
    if let rpe, rpe < E1RMPolicy.minimumEligibleRPE { return false }
    if reps > E1RMPolicy.maximumEligibleReps { return false }
    if family == .deadlift, reps > E1RMPolicy.maximumEligibleDeadliftReps { return false }
    return true
  }

  /// History points only exist for completed, non-failed sets; their stored
  /// reps and RPE are still rechecked so pre-spec history uses the same gate.
  static func isEligible(point: E1RMHistoryPoint, family: LiftFamily?) -> Bool {
    isEligible(reps: point.sourceReps, rpe: point.sourceRPE, family: family)
  }
}
