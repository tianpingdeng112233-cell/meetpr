import Testing

@testable import StudentKit

// Exercise-card note display policy (David 2026-07-18): while a set is active
// the hero card owns the note, so the per-exercise card shows it only on
// review (no active set — day finished or browsed read-only).

@Test func reviewNoteHiddenWhileASetIsActive() {
  #expect(CoachNoteDisplay.reviewNote(activeIndex: 0, notes: "节奏310") == nil)
  #expect(CoachNoteDisplay.reviewNote(activeIndex: 3, notes: "节奏310") == nil)
}

@Test func reviewNoteShownWhenNoSetIsActive() {
  #expect(CoachNoteDisplay.reviewNote(activeIndex: nil, notes: "节奏310") == "节奏310")
}

@Test func reviewNoteTrimsAndDropsEmptyNotes() {
  #expect(CoachNoteDisplay.reviewNote(activeIndex: nil, notes: "  顶组留一  ") == "顶组留一")
  #expect(CoachNoteDisplay.reviewNote(activeIndex: nil, notes: "   ") == nil)
  #expect(CoachNoteDisplay.reviewNote(activeIndex: nil, notes: nil) == nil)
}
