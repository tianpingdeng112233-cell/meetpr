import Testing

@testable import StudentKit

// spec 043 §G — the set row surfaces the coach cue (and only when meaningful).

@Test func setRowShowsTrimmedCoachNote() {
  #expect(SetRecordRow.displayCoachNote("70%top") == "70%top")
  #expect(SetRecordRow.displayCoachNote("  节奏3-1-0 ") == "节奏3-1-0")
}

@Test func setRowHidesBlankCoachNote() {
  #expect(SetRecordRow.displayCoachNote(nil) == nil)
  #expect(SetRecordRow.displayCoachNote("") == nil)
  #expect(SetRecordRow.displayCoachNote("   ") == nil)
}
