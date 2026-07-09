import Testing

@testable import StudentKit

// spec 043 §G — the set row surfaces the coach cue (and only when meaningful).

@Test func setRowShowsTrimmedCoachNote() {
  #expect(CoachNoteDisplay.text("70%top") == "70%top")
  #expect(CoachNoteDisplay.text("  节奏3-1-0 ") == "节奏3-1-0")
}

@Test func setRowHidesBlankCoachNote() {
  #expect(CoachNoteDisplay.text(nil) == nil)
  #expect(CoachNoteDisplay.text("") == nil)
  #expect(CoachNoteDisplay.text("   ") == nil)
}
