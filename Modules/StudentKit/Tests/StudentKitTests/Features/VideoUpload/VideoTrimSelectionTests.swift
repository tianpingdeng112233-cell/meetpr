import Testing

@testable import StudentKit

@Test func shortVideoTrimDefaultsToFullSelection() {
  let selection = VideoTrimSelection(sourceDurationSeconds: 42, maxDurationSeconds: 120)

  #expect(selection.startSeconds == 0)
  #expect(selection.endSeconds == 42)
  #expect(selection.durationSeconds == 42)
  #expect(selection.isValid)
}

@Test func longVideoTrimDefaultsToMaximumDuration() {
  let selection = VideoTrimSelection(sourceDurationSeconds: 180, maxDurationSeconds: 120)

  #expect(selection.startSeconds == 0)
  #expect(selection.endSeconds == 120)
  #expect(selection.durationSeconds == 120)
}

@Test func trimSelectionNeverExceedsMaximumWhenStartLeadsTheDrag() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 180, maxDurationSeconds: 120)
  selection.moveStart(to: 30)
  selection.moveEnd(to: 150)

  selection.moveStart(to: 0)

  // Start follows the finger to 0; end is pulled back to keep the 120s window.
  #expect(selection.startSeconds == 0)
  #expect(selection.endSeconds == 120)
  #expect(selection.durationSeconds == 120)
}

@Test func trimSelectionNeverExceedsMaximumWhenEndLeadsTheDrag() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 180, maxDurationSeconds: 120)
  selection.moveStart(to: 30)

  selection.moveEnd(to: 180)

  // End follows the finger to the source tail; start is pushed to hold 120s.
  #expect(selection.startSeconds == 60)
  #expect(selection.endSeconds == 180)
  #expect(selection.durationSeconds == 120)
}

@Test func trimHandlesClampToSourceAndKeepNonemptySelection() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 30, maxDurationSeconds: 120)

  selection.moveStart(to: 100)
  #expect(selection.startSeconds == 29.9)
  #expect(selection.endSeconds == 30)

  selection.moveEnd(to: -100)

  // End follows the finger to the head; start is pushed back off it.
  #expect(selection.startSeconds == 0)
  #expect(abs(selection.endSeconds - 0.1) < 0.000_001)
  #expect(abs(selection.durationSeconds - 0.1) < 0.000_001)
}

@Test func trimEndHandlePushesStartWhenDraggedPastTheWindow() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 300, maxDurationSeconds: 120)

  selection.moveEnd(to: 150)

  #expect(selection.endSeconds == 150)
  #expect(selection.startSeconds == 30)
  #expect(selection.durationSeconds == 120)
}

@Test func trimStartHandlePushesEndWhenDraggedPastTheWindow() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 300, maxDurationSeconds: 120)
  selection.moveEnd(to: 90)

  selection.moveStart(to: 200)

  #expect(selection.startSeconds == 200)
  #expect(selection.endSeconds == 200.1)
  #expect(abs(selection.durationSeconds - 0.1) < 0.000_001)
}

@Test func trimStartHandlePushesEndOutToTheWindowMaximum() {
  var selection = VideoTrimSelection(sourceDurationSeconds: 300, maxDurationSeconds: 120)
  selection.moveEnd(to: 300)

  selection.moveStart(to: 100)

  #expect(selection.startSeconds == 100)
  #expect(selection.endSeconds == 220)
  #expect(selection.durationSeconds == 120)
}
