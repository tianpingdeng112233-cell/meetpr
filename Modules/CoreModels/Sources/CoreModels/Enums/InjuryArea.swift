import Foundation

/// Injury body-area tag (spec 032 Step 7).
/// Mirrors backend INJURY_AREAS verbatim (src/db/types.ts).
public enum InjuryArea: String, Codable, Hashable, Sendable, CaseIterable {
  case shoulder = "shoulder"
  case elbow = "elbow"
  case wrist = "wrist"
  case lowerBack = "lower_back"
  case hip = "hip"
  case knee = "knee"
  case ankle = "ankle"
  case other = "other"
}
