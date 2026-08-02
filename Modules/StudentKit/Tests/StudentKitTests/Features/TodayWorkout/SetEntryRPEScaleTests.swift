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

  /// Strip geometry on a 393pt phone: the set-entry sheet leaves the tick strip
  /// ~329pt, split into 11 cells with the view's 3pt gaps.
  private static let stripWidth = 329.0
  private static let tickSpacing = 3.0

  @Test func cellGeometryAccountsForTheGapsBetweenTicks() {
    let cell = SetEntryRPE.cellWidth(width: Self.stripWidth, spacing: Self.tickSpacing)
    // 11 cells + 10 gaps have to add back up to the strip.
    #expect(abs(cell * 11 + Self.tickSpacing * 10 - Self.stripWidth) < 1e-9)

    let first = SetEntryRPE.centerX(
      ofIndex: 0, width: Self.stripWidth, spacing: Self.tickSpacing)
    let last = SetEntryRPE.centerX(
      ofIndex: 10, width: Self.stripWidth, spacing: Self.tickSpacing)
    #expect(abs(first - cell / 2) < 1e-9)
    #expect(abs(last - (Self.stripWidth - cell / 2)) < 1e-9)
  }

  @Test func valueSnapsToTheNearestTickCentre() {
    // Every bar centre resolves to its own stop — the guarantee the old
    // spacing-blind floor split broke by 1–3pt at the far end.
    for index in 0..<SetEntryRPE.cellCount {
      let center = SetEntryRPE.centerX(
        ofIndex: index, width: Self.stripWidth, spacing: Self.tickSpacing)
      let expected = 5.0 + Double(index) * 0.5
      #expect(
        SetEntryRPE.value(atX: center, width: Self.stripWidth, spacing: Self.tickSpacing)
          == expected)
    }
  }

  @Test func valueRoundsAtTheMidpointBetweenTwoTicks() {
    let cell = SetEntryRPE.cellWidth(width: Self.stripWidth, spacing: Self.tickSpacing)
    let pitch = cell + Self.tickSpacing
    let firstCenter = SetEntryRPE.centerX(
      ofIndex: 0, width: Self.stripWidth, spacing: Self.tickSpacing)
    let midpoint = firstCenter + pitch / 2

    #expect(
      SetEntryRPE.value(atX: midpoint - 0.5, width: Self.stripWidth, spacing: Self.tickSpacing)
        == 5.0)
    #expect(
      SetEntryRPE.value(atX: midpoint + 0.5, width: Self.stripWidth, spacing: Self.tickSpacing)
        == 5.5)
  }

  @Test func valueClampsOutsideTheStrip() {
    #expect(SetEntryRPE.value(atX: -20, width: Self.stripWidth, spacing: Self.tickSpacing) == 5.0)
    #expect(SetEntryRPE.value(atX: 0, width: Self.stripWidth, spacing: Self.tickSpacing) == 5.0)
    #expect(
      SetEntryRPE.value(atX: Self.stripWidth, width: Self.stripWidth, spacing: Self.tickSpacing)
        == 10.0)
    #expect(SetEntryRPE.value(atX: 900, width: Self.stripWidth, spacing: Self.tickSpacing) == 10.0)
    #expect(SetEntryRPE.value(atX: 55, width: 0, spacing: Self.tickSpacing) == 5.0)  // zero width
  }

  @Test func valueRejectsStripsTooNarrowToHoldElevenCells() {
    // 11 cells plus 10 gaps need more than 30pt at 3pt spacing. At or below it
    // `cellWidth` goes non-positive while `cellWidth + spacing` stays positive,
    // so without its own guard the hit test would return stops that don't line
    // up with any drawn bar.
    #expect(SetEntryRPE.cellWidth(width: 30, spacing: Self.tickSpacing) == 0)
    #expect(SetEntryRPE.cellWidth(width: 20, spacing: Self.tickSpacing) < 0)
    #expect(SetEntryRPE.value(atX: 10, width: 30, spacing: Self.tickSpacing) == 5.0)
    #expect(SetEntryRPE.value(atX: 10, width: 20, spacing: Self.tickSpacing) == 5.0)
    #expect(SetEntryRPE.centerX(ofIndex: 5, width: 20, spacing: Self.tickSpacing) == 0)
    // Just above the floor the geometry is real again.
    #expect(SetEntryRPE.cellWidth(width: 41, spacing: Self.tickSpacing) == 1)
    #expect(SetEntryRPE.value(atX: 41, width: 41, spacing: Self.tickSpacing) == 10.0)
  }

  @Test func indexRoundTripsEveryStop() {
    for index in 0..<SetEntryRPE.cellCount {
      #expect(SetEntryRPE.index(for: 5.0 + Double(index) * 0.5) == index)
    }
    #expect(SetEntryRPE.index(for: 8.2) == 6)  // snaps first
    #expect(SetEntryRPE.index(for: 99) == 10)  // clamps first
  }

  @Test func scrubIntentStaysUndecidedUntilTheFingerTravels() {
    #expect(SetEntryRPE.intent(forTranslation: .zero) == .idle)
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: 3, height: 2)) == .idle)
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: -3, height: -4)) == .idle)
  }

  @Test func lockedIntentHoldsForTheRestOfTheGesture() {
    // Undecided keeps re-deriving until the finger commits.
    #expect(
      SetEntryRPE.lockedIntent(current: .idle, translation: CGSize(width: 2, height: 1))
        == .idle)
    #expect(
      SetEntryRPE.lockedIntent(current: .idle, translation: CGSize(width: 20, height: 2))
        == .scrub)

    // A locked scrub survives being dragged back to the exact start point —
    // otherwise the release would fall through to the tap branch and write the
    // touch-down cell instead of the value the student scrubbed to.
    #expect(SetEntryRPE.lockedIntent(current: .scrub, translation: .zero) == .scrub)
    #expect(
      SetEntryRPE.lockedIntent(current: .scrub, translation: CGSize(width: 1, height: 40))
        == .scrub)

    // A locked scroll never comes back to write a value, however far sideways
    // the finger wanders later.
    #expect(SetEntryRPE.lockedIntent(current: .scroll, translation: .zero) == .scroll)
    #expect(
      SetEntryRPE.lockedIntent(current: .scroll, translation: CGSize(width: 90, height: 2))
        == .scroll)
  }

  @Test func onlyAnUncommittedTouchWritesOnRelease() {
    #expect(SetEntryRPE.commitsOnRelease(intent: .idle))  // a tap
    #expect(!SetEntryRPE.commitsOnRelease(intent: .scrub))  // already written live
    #expect(!SetEntryRPE.commitsOnRelease(intent: .scroll))  // must never write
  }

  @Test func aScrollThatReturnsToItsStartStillRefusesToWrite() {
    // The regression this pairing exists to prevent: judging the release by
    // final displacement alone called this a tap and wrote an RPE, because a
    // scroll driven back to its origin ends with zero translation.
    var intent = SetEntryRPE.ScrubIntent.idle
    for translation in [
      CGSize(width: 1, height: 8),  // locks .scroll
      CGSize(width: 1, height: 20),
      CGSize(width: 0, height: 4),  // ...on the way back
      CGSize.zero,  // released exactly where it started
    ] {
      intent = SetEntryRPE.lockedIntent(current: intent, translation: translation)
    }
    #expect(intent == .scroll)
    #expect(!SetEntryRPE.commitsOnRelease(intent: intent))
  }

  @Test func aFlickThatCrossesTheThresholdOnItsLastFrameStillScrubs() {
    // The other half: intent is locked in the same callback that writes, so a
    // gesture whose final frame is the first to cross the threshold is a scrub
    // — never a gesture that falls through both branches writing nothing.
    var intent = SetEntryRPE.ScrubIntent.idle
    intent = SetEntryRPE.lockedIntent(current: intent, translation: CGSize(width: 2, height: 1))
    #expect(intent == .idle)
    intent = SetEntryRPE.lockedIntent(current: intent, translation: CGSize(width: 18, height: 3))
    #expect(intent == .scrub)
    #expect(!SetEntryRPE.commitsOnRelease(intent: intent))
  }

  @Test func scrubIntentSplitsHorizontalFromVertical() {
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: 20, height: 4)) == .scrub)
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: -20, height: 4)) == .scrub)
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: 4, height: 20)) == .scroll)
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: 4, height: -20)) == .scroll)
    // A perfect diagonal keeps the pre-existing tie-break: horizontal wins.
    #expect(SetEntryRPE.intent(forTranslation: CGSize(width: 10, height: 10)) == .scrub)
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
