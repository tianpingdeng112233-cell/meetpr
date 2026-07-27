import Foundation
import Testing

@testable import StudentKit

/// The RPE tick-scale replaced the +/- stepper; these lock in the pure bucket /
/// snap / describe math and the Double↔text bridge the view leans on, including
/// the boundaries the review flagged (non-0.5 seed, end clamps, zero width).
@Suite struct SetEntryRPEScaleTests {
  @Test func snapClampsAndRoundsToHalfSteps() {
    #expect(SetEntryRPE.snap(8.2) == 8.0)
    #expect(SetEntryRPE.snap(8.3) == 8.5)
    #expect(SetEntryRPE.snap(8.5) == 8.5)
    #expect(SetEntryRPE.snap(4.0) == 5.0)  // clamp low
    #expect(SetEntryRPE.snap(11.0) == 10.0)  // clamp high
  }

  @Test func valueBucketsTouchXIntoElevenStops() {
    #expect(SetEntryRPE.value(atX: 0, width: 110) == 5.0)
    #expect(SetEntryRPE.value(atX: 110, width: 110) == 10.0)  // last bucket clamps
    #expect(SetEntryRPE.value(atX: 55, width: 110) == 7.5)  // floor(0.5 * 11) = 5
    #expect(SetEntryRPE.value(atX: -20, width: 110) == 5.0)  // negative clamps
    #expect(SetEntryRPE.value(atX: 200, width: 110) == 10.0)  // past end clamps
    #expect(SetEntryRPE.value(atX: 55, width: 0) == 5.0)  // zero-width guard
  }

  @Test func descriptionMapsEveryHalfStepToRIRCopy() {
    let expected = [
      "还能多做 5 次",
      "还能多做 4-5 次",
      "还能多做 4 次",
      "还能多做 3-4 次",
      "还能多做 3 次",
      "还能多做 2-3 次",
      "还能多做 2 次",
      "还能多做 1-2 次",
      "还能多做 1 次",
      "或许还能多做 1 次",
      "力竭，无保留",
    ]
    #expect(SetEntryRPE.descriptions == expected)
    for (index, copy) in expected.enumerated() {
      #expect(SetEntryRPE.description(5 + Double(index) * 0.5) == copy)
    }
    #expect(SetEntryRPE.description(8.2) == "还能多做 2 次")  // snaps before describing
    #expect(SetEntryRPE.description(4.0) == "还能多做 5 次")  // clamp low
    #expect(SetEntryRPE.description(11.0) == "力竭，无保留")  // clamp high
  }

  @Test func tickHeightsAndLitRangeMatchV3Contract() {
    #expect(SetEntryRPE.barHeight(for: 8.5, selectedValue: 8.5) == 32)
    #expect(SetEntryRPE.barHeight(for: 8.0, selectedValue: 8.5) == 22)
    #expect(SetEntryRPE.barHeight(for: 7.5, selectedValue: 8.5) == 13)
    #expect(SetEntryRPE.isLit(8.5, selectedValue: 8.5))
    #expect(!SetEntryRPE.isLit(9.0, selectedValue: 8.5))
  }

  @Test func rpeTextBridgeSnapsClampsAndRoundTrips() {
    #expect(SetEntryValue.rpeText(8.0) == "8")
    #expect(SetEntryValue.rpeText(8.5) == "8.5")
    #expect(SetEntryValue.rpeText(11.0) == "10")  // clamp high
    #expect(SetEntryValue.rpeText(4.0) == "5")  // clamp low
    // Round-trips back through the text parser the view saves from.
    #expect(SetEntryValue.rpe(from: SetEntryValue.rpeText(8.5)) == Decimal(string: "8.5"))
  }

  @Test func decimalSnapAlignsNonHalfStepSeed() {
    // Exact rational literals (no force-unwrapped Decimal(string:)).
    #expect(SetEntryValue.snapRPE(Decimal(82) / 10) == 8)  // 8.2 → 8.0
    #expect(SetEntryValue.snapRPE(Decimal(775) / 100) == 8)  // 7.75 → 8.0
    #expect(SetEntryValue.snapRPE(Decimal(95) / 10) == Decimal(95) / 10)  // 9.5 stays
  }
}
