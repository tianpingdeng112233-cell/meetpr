import DesignSystem
import SwiftUI
import Testing

@testable import StudentKit

@Suite("Black-gold status color semantics")
struct StatusColorSemanticsTests {
  @Test("not-started training is an unfinished danger state")
  func notStartedTrainingUsesDangerTone() {
    #expect(TrainingDayCompletionState.notStarted.semanticTone == .notCompleted)
    #expect(TrainingDayCompletionState.partial.semanticTone == .inProgress)
    #expect(TrainingDayCompletionState.complete.semanticTone == .completed)
  }

  @Test("count badges are red, destructive account actions use danger")
  func unreadAndDestructiveActionsUseDanger() {
    #expect(StudentVisualSemantics.unread == .unreadBadge)
    #expect(StudentVisualSemantics.destructiveAction == .danger)
  }

  @Test("an inline new-item dot is gold, not a red count badge")
  func inlineNewItemDotIsGold() {
    #expect(MeetPRSemanticTone.inProgress.color == Color.MeetPR.gold500)
    #expect(MeetPRSemanticTone.unreadBadge.color != MeetPRSemanticTone.danger.color)
  }
}
