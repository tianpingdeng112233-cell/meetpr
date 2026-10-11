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

@Test func editableHeroSeparatesExerciseAndSetNotes() {
  #expect(
    CoachNoteDisplay.heroExerciseNote(isEditable: true, notes: "  Pause 2 seconds  ")
      == "Pause 2 seconds")
  #expect(CoachNoteDisplay.heroExerciseNote(isEditable: true, notes: nil) == nil)
  #expect(CoachNoteDisplay.heroExerciseNote(isEditable: true, notes: " \n ") == nil)
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: true, notes: "Exercise", coachNote: "Tempo")
      == "Tempo")
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: true, notes: nil, coachNote: "Tempo")
      == "Tempo")
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: true, notes: "Exercise", coachNote: nil) == nil)
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: true, notes: "Exercise", coachNote: "  ") == nil)
}

@Test func readOnlyHeroKeepsIOSExerciseNoteRegardlessOfSetNote() {
  #expect(CoachNoteDisplay.heroExerciseNote(isEditable: false, notes: "Exercise") == nil)
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: false, notes: "Exercise", coachNote: "Tempo")
      == "Exercise")
  #expect(
    CoachNoteDisplay.heroLowerNote(isEditable: false, notes: "Exercise", coachNote: nil)
      == "Exercise")
  #expect(CoachNoteDisplay.heroLowerNote(isEditable: false, notes: nil, coachNote: "Tempo") == nil)
}
