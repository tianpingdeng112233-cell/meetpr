import Foundation
import Testing

@testable import CoreModels

/// Spec 106: the extended RPE table below is copied from the SPEC document
/// (independent of the implementation's table) so any formula/table drift in
/// E1RMCalculator fails here. Rows reps 1-12, columns RPE 6.0...10.0 step 0.5.
private let specRTSTable: [[Double]] = [
  [0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955, 0.978, 1],
  [0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955],
  [0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922],
  [0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892],
  [0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863],
  [0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837],
  [0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811],
  [0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786],
  [0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762],
  [0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739],
  [0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707],
  [0.572, 0.5855, 0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68],
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
          abs(actual - expected) < 1e-10,
          "reps=\(reps) rpe=\(rpe): got \(actual), spec table says \(expected)"
        )
      }
    }
  }
}

@Test func spec106CanonicalFixture() {
  // 100kg × 5 @ RPE 8 → intensity 0.811 → ≈123.30 kg (spec 106 C1).
  let result = E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: 8.0)
  #expect(result != nil)
  if let result { #expect(abs(result - 123.30) < 0.01) }
}

@Test(arguments: [(3, 9.0, 112.11), (1, 10.0, 100.0), (11, 8.0, 153.14), (12, 8.0, 159.74)])
func extendedTableCanonicalExamples(reps: Int, rpe: Double, expected: Double) throws {
  let actual = try #require(E1RMCalculator.calculate(weightKg: 100, reps: reps, rpe: rpe))
  #expect(abs(actual - expected) < 0.01)
}

@Test func extendedTableSuggestedWeightPreservesRawRoundTrip() throws {
  let suggested = try #require(E1RMCalculator.suggestedWeight(e1RM: 123.3, reps: 2, rpe: 9))
  // The calculator returns raw kg; the existing prescription layer rounds to 2.5 kg.
  #expect(abs(suggested - 113.6826) < 1e-10)
  let estimate = try #require(E1RMCalculator.calculate(weightKg: 100, reps: 5, rpe: 8))
  let roundTrip = try #require(E1RMCalculator.suggestedWeight(e1RM: estimate, reps: 5, rpe: 8))
  #expect(abs(roundTrip - 100) < 1e-10)
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
  // reps=5: RPE 7.5 → 0.799, RPE 8 → 0.811 ⇒ RPE 7.75 → 0.805.
  let cases: [(Double, Double)] = [
    (7.75, 100 / 0.805),
    (7.25, 100 / 0.7925),
    (9.25, 100 / 0.8435),
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

@Test func suggestedWeightReversesRTSTable() throws {
  let suggested = try #require(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: 10))
  #expect(abs(suggested - 86.3) < 0.001)

  let roundTrip = E1RMCalculator.calculate(weightKg: suggested, reps: 5, rpe: 10)
  #expect(roundTrip != nil)
  if let roundTrip {
    #expect(abs(roundTrip - 100) < 0.001)
  }
}

@Test func suggestedWeightExtrapolatesToRPEFive() throws {
  let rpeFivePointFive = try #require(
    E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: 5.5))
  let rpeFive = try #require(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: 5))

  #expect(abs(rpeFivePointFive - 75) < 0.001)
  #expect(abs(rpeFive - 73.8) < 0.001)
}

@Test func suggestedWeightRejectsInputsOutsideReverseTable() {
  #expect(E1RMCalculator.suggestedWeight(e1RM: 0, reps: 5, rpe: 8) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: -100, reps: 5, rpe: 8) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 0, rpe: 8) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 13, rpe: 8) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: 4.5) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: 10.5) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: .infinity, reps: 5, rpe: 8) == nil)
  #expect(E1RMCalculator.suggestedWeight(e1RM: 100, reps: 5, rpe: .nan) == nil)
}
