import Foundation
import Testing

@testable import StudentKit

/// The set-entry fields bind to text and parse on commit; these lock in the
/// "type a value then save" contract (the focus-loss parse race the value:format:
/// binding had) plus the range clamps.
@Suite struct SetEntryValueTests {
  @Test func parsesMultiDigitAndDecimal() {
    #expect(SetEntryValue.weight(from: "150") == 150)
    #expect(SetEntryValue.weight(from: "172.5") == Decimal(string: "172.5"))
    #expect(SetEntryValue.reps(from: "10") == 10)
    #expect(SetEntryValue.rpe(from: "9.5") == Decimal(string: "9.5"))
  }

  @Test func rpeTenIsNotTruncated() {
    // The multi-digit case the reviewer flagged: "10" must not clamp to 5 or 1.
    #expect(SetEntryValue.rpe(from: "10") == 10)
  }

  @Test func clampsOutOfRangeOnCommit() {
    #expect(SetEntryValue.rpe(from: "108.5") == 10)  // fat-fingered high
    #expect(SetEntryValue.rpe(from: "3") == 5)  // below floor
    #expect(SetEntryValue.weight(from: "-20") == 0)  // never negative
    #expect(SetEntryValue.reps(from: "-4") == 0)
  }

  @Test func commaDecimalIsNormalized() {
    // `.decimalPad` enters "," in some locales; must not save 172 for 172,5.
    #expect(SetEntryValue.weight(from: "172,5") == Decimal(string: "172.5"))
    #expect(SetEntryValue.rpe(from: "8,5") == Decimal(string: "8.5"))
  }

  @Test func emptyOrGarbageFallsBackSafely() {
    #expect(SetEntryValue.weight(from: "") == 0)
    #expect(SetEntryValue.reps(from: "") == 0)
    #expect(SetEntryValue.rpe(from: "") == 5)  // clamps up to the floor
    #expect(SetEntryValue.weight(from: "abc") == 0)
  }

  @Test func textRoundTripsWithoutTrailingZeros() {
    #expect(SetEntryValue.weight(from: SetEntryValue.text(175)) == 175)
    #expect(SetEntryValue.text(175) == "175")
  }
}

@Test func fieldReEditCountsCompletedEditSessionsNotKeystrokes() {
  var tracker = SetEntryFieldEditTracker()

  tracker.begin(value: "")
  #expect(tracker.finish(value: "100") == nil)
  tracker.begin(value: "100")
  #expect(tracker.finish(value: "105") == 2)
  tracker.begin(value: "105")
  #expect(tracker.finish(value: "105") == nil)
}

// Spec 072 E2: an empty weight box must not complete (it would log 0kg),
// while an explicit "0" stays legal for bodyweight work.
@Test(arguments: [
  ("", false),
  ("   ", false),
  ("0", true),
  ("142.5", true),
])
func completionEligibilityRequiresExplicitWeight(text: String, allowed: Bool) {
  #expect(SetEntryValue.allowsCompletion(weightText: text) == allowed)
}

@Test("Badge-facing parsers hide untouched fields instead of clamping them")
func enteredValuesHideBlankFields() {
  #expect(SetEntryValue.enteredRPE(from: "") == nil)
  #expect(SetEntryValue.enteredRPE(from: "  ") == nil)
  #expect(SetEntryValue.enteredRPE(from: "8.5") == 8.5)
  #expect(SetEntryValue.enteredWeight(from: "") == nil)
  #expect(SetEntryValue.enteredWeight(from: "180") == 180)
  #expect(SetEntryValue.enteredReps(from: "") == nil)
  #expect(SetEntryValue.enteredReps(from: "4") == 4)
  // The legacy parsers keep their clamped placeholders for the form itself.
  #expect(SetEntryValue.rpe(from: "") == 5)
}
