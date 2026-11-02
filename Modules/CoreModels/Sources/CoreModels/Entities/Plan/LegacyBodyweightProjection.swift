import Foundation

/// Exact compatibility encoding emitted for bodyweight by the backend.
/// A marker alone must never replace a real weight or another RPE target.
public func isLegacyBodyweightProjection(
  loadMode: PlanLoadMode?,
  intensityMode: IntensityMode?,
  targetValue: Decimal?,
  coachNote: String?
) -> Bool {
  loadMode == nil && intensityMode == .rpe && targetValue == 10
    && coachNote?.range(
      of: "自重|bodyweight", options: [.regularExpression, .caseInsensitive]) != nil
}
