import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// Spec 112 iOS follow-up: warm-up and extra sets (and student-added rows) delete by swiping left.
struct AllDaySwipeDeleteTests {
  @Test func onlyStudentOwnedRowsOutsideTheEditorCanSwipe() {
    #expect(AllDaySwipeDelete.canSwipe(isRemovableRow: true, editable: true, editing: false))
    #expect(!AllDaySwipeDelete.canSwipe(isRemovableRow: false, editable: true, editing: false))
    #expect(!AllDaySwipeDelete.canSwipe(isRemovableRow: true, editable: false, editing: false))
    #expect(!AllDaySwipeDelete.canSwipe(isRemovableRow: true, editable: true, editing: true))
  }

  @Test func horizontalDragFollowsFingerButNeverPastTheRevealOrRightward() {
    let width = AllDaySwipeDelete.revealWidth
    #expect(
      AllDaySwipeDelete.offset(open: false, translation: CGSize(width: -30, height: 4)) == -30)
    #expect(AllDaySwipeDelete.offset(open: false, translation: CGSize(width: 40, height: 0)) == 0)
    #expect(
      AllDaySwipeDelete.offset(open: false, translation: CGSize(width: -400, height: 0))
        == -width * 1.2)
    #expect(
      AllDaySwipeDelete.offset(open: true, translation: CGSize(width: 30, height: 0)) == -width + 30
    )
  }

  @Test func verticalDragsBelongToTheScrollView() {
    #expect(
      AllDaySwipeDelete.offset(open: false, translation: CGSize(width: -30, height: 60)) == nil)
    #expect(
      !AllDaySwipeDelete.settlesOpen(open: false, translation: CGSize(width: -80, height: 120)))
  }

  @Test func releaseSnapsOpenPastHalfAndClosesOtherwise() {
    let half = AllDaySwipeDelete.revealWidth / 2
    #expect(
      AllDaySwipeDelete.settlesOpen(open: false, translation: CGSize(width: -half - 1, height: 0)))
    #expect(
      !AllDaySwipeDelete.settlesOpen(open: false, translation: CGSize(width: -half + 1, height: 0)))
    #expect(
      !AllDaySwipeDelete.settlesOpen(open: true, translation: CGSize(width: half + 1, height: 0)))
    #expect(AllDaySwipeDelete.settlesOpen(open: true, translation: CGSize(width: 10, height: 0)))
  }
}
