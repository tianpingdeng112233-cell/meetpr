import Foundation
import Testing

@testable import CoreModels

/// Spec 050 §5: graded anomaly guard. A single mis-logged set (P1-1 numeric
/// keyboard makes 175→275 easy) must not poison current/best/PR. Classify the
/// new e1RM against the prior .normal running best.
@Test func classifierColdStartIsNormal() {
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 200, priorNormalBestKg: nil) == .normal)
}

@Test func classifierZeroOrNegativeBaselineIsNormal() {
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 200, priorNormalBestKg: 0) == .normal)
}

@Test func classifierSmallWobbleIsNormal() {
  // +2% is inside the day-to-day noise floor.
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 204, priorNormalBestKg: 200) == .normal)
}

@Test func classifierBelowBaselineIsNormal() {
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 180, priorNormalBestKg: 200) == .normal)
}

@Test func classifierAtSoftBoundaryIsNormal() {
  // Exactly +10% (soft ceiling, inclusive) still counts as a real PR.
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 220, priorNormalBestKg: 200) == .normal)
}

@Test func classifierJustAboveSoftIsLowConfidence() {
  // +12% — unusual for a single session (real gains run 0–5%); downweight.
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 224, priorNormalBestKg: 200) == .lowConfidence)
}

@Test func classifierAtHardBoundaryIsLowConfidence() {
  // Exactly +18% (hard ceiling, inclusive) is still low-confidence, not suspect.
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 236, priorNormalBestKg: 200) == .lowConfidence)
}

@Test func classifierAboveHardIsSuspect() {
  // +75% (a 175→275 typo) is physiologically impossible in one session.
  #expect(E1RMAnomalyClassifier.classify(newE1RMKg: 350, priorNormalBestKg: 200) == .suspectHard)
}

@Test func classifierThresholdsAreLockedConstants() {
  #expect(E1RMAnomalyClassifier.softJump == 0.10)
  #expect(E1RMAnomalyClassifier.hardJump == 0.18)
}
