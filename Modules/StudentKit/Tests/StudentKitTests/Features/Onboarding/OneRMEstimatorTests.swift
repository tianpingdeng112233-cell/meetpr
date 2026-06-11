import CoreModels
import Foundation
import Testing

@testable import StudentKit

// Acceptance fixture (spec 032): 100kg × 5 @ RPE8 → RTS intensity 0.78 →
// raw e1RM 128.205… → 128.0 on the 0.5 grid; 90% of raw = 115.385 → 115.5.

@Test func estimatorMatchesSpec028Fixture() {
  let estimate = OneRMEstimator.estimate(weightKg: 100, reps: 5, rpe: 8)
  #expect(estimate?.estimated == Decimal(128))
  #expect(estimate?.conservative == Decimal(string: "115.5"))
}

@Test func conservativeIsNinetyPercentOfRawNotRounded() {
  // If 90% were taken from the ROUNDED estimate (128.0), the result would
  // be 115.0 — the wiki copy expects 115.5 (raw → 90% → grid).
  let estimate = OneRMEstimator.estimate(weightKg: 100, reps: 5, rpe: 8)
  #expect(estimate?.conservative != Decimal(115))
}

@Test func estimatesSnapToHalfKiloGrid() {
  guard let estimate = OneRMEstimator.estimate(weightKg: 117.5, reps: 3, rpe: 8.5) else {
    Issue.record("expected estimate")
    return
  }
  let doubled = estimate.estimated * 2
  #expect(doubled == UnitDisplay.rounded(doubled, scale: 0))
}

@Test func invalidInputsProduceNoEstimate() {
  #expect(OneRMEstimator.estimate(weightKg: 0, reps: 5, rpe: 8) == nil)
  #expect(OneRMEstimator.estimate(weightKg: 100, reps: 0, rpe: 8) == nil)
  #expect(OneRMEstimator.estimate(weightKg: 100, reps: 5, rpe: 10.5) == nil)
}

// MARK: - Unit lens round trips (spec 032 D1 / risk 9)

@Test func weightLensRoundTripsWithoutDrift() {
  // 83 kg → "183" lb (rounded 0.1) → parse back → 83.01 kg ≈ 83 within
  // the 2-decimal wire grid; assert the displayed string is stable.
  let lbText = UnitDisplay.weightText(kg: 83, unit: .lb)
  #expect(lbText == "183")
  let backToKg = UnitDisplay.parseWeight(lbText, unit: .lb)
  #expect(backToKg != nil)
  let redisplayed = UnitDisplay.weightText(kg: backToKg, unit: .lb)
  #expect(redisplayed == lbText)  // no creep on repeated toggles
}

@Test func switchingUnitNeverMutatesStoredMetric() {
  let kilograms = UnitDisplay.parseWeight("83", unit: .kg)
  #expect(kilograms == 83)
  // Rendering in lb is presentation only.
  _ = UnitDisplay.weightText(kg: kilograms, unit: .lb)
  #expect(kilograms == 83)
}

@Test func heightLensConvertsToInches() {
  #expect(UnitDisplay.heightText(cm: 178, unit: .lb) == "70.1")
  let parsed = UnitDisplay.parseHeight("70.1", unit: .lb)
  #expect(parsed.map { UnitDisplay.heightText(cm: $0, unit: .lb) } == "70.1")
}

@Test func parserRejectsGarbageAndOutOfRangeOneRM() {
  #expect(UnitDisplay.parseWeight("abc", unit: .kg) == nil)
  #expect(UnitDisplay.parseOneRM("0") == nil)
  #expect(UnitDisplay.parseOneRM("1000") == nil)
  #expect(UnitDisplay.parseOneRM("180.5") == Decimal(string: "180.5"))
}
