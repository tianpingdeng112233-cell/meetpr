import Foundation
import Testing

@testable import CoreModels

/// Spec 028 §2 lock: the RTS table below is copied from the SPEC document
/// (independent of the implementation's table) so any formula/table drift in
/// E1RMCalculator fails here. Rows reps 1-12, columns RPE 6.0...10.0 step 0.5.
private let specRTSTable: [[Double]] = [
  [0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96, 0.98, 1.00],
  [0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96],
  [0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92],
  [0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88],
  [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86],
  [0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84],
  [0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82],
  [0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80],
  [0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78],
  [0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76],
  [0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74],
  [0.56, 0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72],
]

@Test func rtsTableAll108CellsMatchSpec() {
  let weight = 100.0
  for (repsIndex, row) in specRTSTable.enumerated() {
    let reps = repsIndex + 1
    for (rpeIndex, intensity) in row.enumerated() {
      let rpe = 6.0 + Double(rpeIndex) * 0.5
      let expected = weight / intensity
      let actual = E1RMCalculator.calculate(weightKg: weight, reps: reps, rpe: rpe)
      #expect(actual != nil, "reps=\(reps) rpe=\(rpe) returned nil")
      if let actual {
        #expect(
          abs(actual - expected) < 0.5,
          "reps=\(reps) rpe=\(rpe): got \(actual), spec table says \(expected)"
        )
      }
    }
  }
}

@Test func spec028CanonicalFixture() {
  // 100kg × 5 @ RPE 8 → intensity 0.78 → ≈128.2 kg (spec 028 §2 callout).
  let result = E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: 8.0)
  #expect(result != nil)
  if let result { #expect(abs(result - 128.2) < 0.1) }
}

private struct EpleyCase {
  let weight: Double
  let reps: Int
  let expected: Double
}

@Test func epleyFallbackWhenRPEMissing() {
  // e1RM = w × (1 + reps/30)
  let cases: [EpleyCase] = [
    EpleyCase(weight: 100, reps: 5, expected: 116.666_67),
    EpleyCase(weight: 140, reps: 1, expected: 144.666_67),
    EpleyCase(weight: 60, reps: 10, expected: 80.0),
  ]
  for testCase in cases {
    let actual = E1RMCalculator.calculate(
      weightKg: testCase.weight, reps: testCase.reps, rpe: nil)
    #expect(actual != nil)
    if let actual {
      #expect(
        abs(actual - testCase.expected) < 0.01,
        "w=\(testCase.weight) r=\(testCase.reps)")
    }
  }
}

@Test func epleyFallbackForSubSixRPE() {
  // rpe in [0, 6.0) is legitimate sub-maximal training → Epley, not nil.
  for rpe in [0.0, 4.0, 5.5] {
    let actual = E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: rpe)
    #expect(actual != nil, "rpe=\(rpe) should fall back to Epley")
    if let actual { #expect(abs(actual - 116.666_67) < 0.01) }
  }
}

@Test func rpeInterpolationBetweenHalfSteps() {
  // 1-D linear interpolation along RPE only (spec 028 §2).
  // reps=5: RPE 8.0 → 0.78, RPE 8.5 → 0.80 ⇒ RPE 8.25 → 0.79.
  let cases: [(Double, Double)] = [
    (8.25, 100 / 0.79),
    (7.25, 100 / 0.75),
    (9.25, 100 / 0.83),
  ]
  for (rpe, expected) in cases {
    let actual = E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: rpe)
    #expect(actual != nil)
    if let actual { #expect(abs(actual - expected) < 0.05, "rpe=\(rpe)") }
  }
}

@Test func boundaryRules() {
  // reps=0 → nil
  #expect(E1RMCalculator.calculate(weightKg: 100, reps: 0, rpe: 8) == nil)
  // weight=0 → nil
  #expect(E1RMCalculator.calculate(weightKg: 0, reps: 5, rpe: 8) == nil)
  // reps=13 saturates to row 12 (RPE path)
  let thirteen = E1RMCalculator.calculate(weightKg: 100, reps: 13, rpe: 10)
  let twelve = E1RMCalculator.calculate(weightKg: 100, reps: 12, rpe: 10)
  #expect(thirteen == twelve)
  // reps=21 without RPE → nil (beyond Epley ceiling)
  #expect(E1RMCalculator.calculate(weightKg: 100, reps: 21, rpe: nil) == nil)
  // rpe > 10 is invalid input → nil, never a silent Epley fallback
  #expect(E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: 10.5) == nil)
  #expect(E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: 11) == nil)
}
