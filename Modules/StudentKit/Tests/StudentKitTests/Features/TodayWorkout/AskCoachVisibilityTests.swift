import CoreModels
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite struct AskCoachVisibilityTests {
  enum Phase: CaseIterable {
    case beforeStarting, recording, allRecorded, settled
  }

  @Test(
    "ask coach follows workout progress independently of theme",
    arguments: Phase.allCases, [ColorScheme.light, .dark])
  func heroVisibility(phase: Phase, theme: ColorScheme) throws {
    var day = try #require(StudentDemoSeed.makePlanView().days.first)
      .replacingCompletion(completedAt: nil, source: nil)
    var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    if phase == .recording { drafts[0].completed = true }
    if phase == .allRecorded {
      for index in drafts.indices { drafts[index].completed = true }
    }
    if phase == .settled {
      // Manual settlement may leave prescribed sets without individual results.
      day = day.replacingCompletion(completedAt: Date(), source: "manual")
    }
    let isEditable = FlexibleTrainingDay.canWrite(day, in: [day])
    let presentation = TodayWorkoutPresentation(
      day: day, drafts: drafts, references: [:], started: phase != .beforeStarting)
    // Visibility has no theme input; both rendered themes consume this same decision.
    let showsAskCoach = SetRefEntryVisibility.shouldShow(
      drafts: drafts, isEditable: isEditable, hasActiveCoach: true, hasSharingContext: true)
    var taps = 0
    let hero = TodayWorkoutHero(
      presentation: presentation, isEditable: isEditable, onStart: {}, onQuickLog: {},
      onEdit: { _ in }, onVideoAction: { _ in }, showsAskCoach: showsAskCoach,
      isPreparingAskCoach: false, onAskCoach: { taps += 1 }
    )
    .environment(\.colorScheme, theme)

    let expected = phase == .beforeStarting || phase == .recording
    #expect(showsAskCoach == expected)
    let button = try? hero.inspect().find(button: StudentStrings.askCoach)
    #expect((button != nil) == expected)
    if expected {
      try #require(button).tap()
      #expect(taps == 1)
    }
  }

  @Test("failed results finish prescribed work; extras do not reopen ask coach")
  func failedSetsAndExtrasDoNotReopenEntry() throws {
    let day = try #require(StudentDemoSeed.makePlanView().days.first)
    var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    for index in drafts.indices { drafts[index].failed = true }
    var extra = drafts[0]
    extra.failed = false
    extra.isExtra = true
    drafts.append(extra)
    var added = extra
    added.isExtra = false
    added.studentAddedDayID = day.id
    drafts.append(added)

    #expect(
      !SetRefEntryVisibility.shouldShow(
        drafts: drafts, isEditable: true, hasActiveCoach: true, hasSharingContext: true))

    drafts[0].assumed = true
    #expect(
      SetRefEntryVisibility.shouldShow(
        drafts: drafts, isEditable: true, hasActiveCoach: true, hasSharingContext: true))
  }
}
