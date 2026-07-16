import Foundation
import Testing

@testable import StudentKit

/// The RPE tick-scale replaced the +/- stepper; these lock in the pure bucket /
/// snap / band math and the Double↔text bridge the view leans on, including the
/// boundaries the review flagged (non-0.5 seed, end clamps, zero width).
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

  @Test func bandMatchesThresholds() {
    #expect(SetEntryRPE.band(5.0) == "留有余力")
    #expect(SetEntryRPE.band(6.5) == "留有余力")
    #expect(SetEntryRPE.band(7.0) == "中高强度")
    #expect(SetEntryRPE.band(8.0) == "中高强度")
    #expect(SetEntryRPE.band(8.5) == "高强度")
    #expect(SetEntryRPE.band(9.0) == "高强度")
    #expect(SetEntryRPE.band(9.5) == "接近极限")
    #expect(SetEntryRPE.band(10.0) == "接近极限")
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
