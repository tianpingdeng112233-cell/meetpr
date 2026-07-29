import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct WorkoutCompletionPresentationTests {
  private struct Fixture {
    let day: StudentPlanDay
    let drafts: [TodayWorkoutViewModel.SetRowDraft]
    let squatExerciseID: UUID
    let benchExerciseID: UUID
  }

  @Test func aggregatesCompletedRowsUsingMockupCompletionRules() throws {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 175, reps: 3, rpe: 8.5)
    complete(&drafts[1], weight: 170, reps: 4, rpe: 8, failed: true)
    complete(&drafts[2], weight: 110, reps: 5, rpe: 8)

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: "李明"
    )

    #expect(presentation.completedSuccessfulSets == 2)
    #expect(presentation.totalPlannedSets == 3)
    #expect(presentation.setCompletionLabel == "降重完成 1 组")
    #expect(presentation.totalReps == 12)
    #expect(presentation.totalVolumeText == "1,755")
    #expect(presentation.mainRPEText == "8.3")
    #expect(presentation.planComparisonText == "符合计划")
    #expect(presentation.metaText == "12 次 · 主项 RPE 8.3 · 符合计划")
    #expect(presentation.coachReceiptText == "李明已收到你的训练日志")
    #expect(presentation.weekDayLabel == "本周第 4 练")
    #expect(presentation.exercises[0].statusText == "2 组 · 1 失败")
    #expect(presentation.exercises[1].statusText == "1 组 全部完成")
  }

  @Test func personalRecordRequiresMoreWeightOrEqualWeightWithMoreReps() {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 175, reps: 4, rpe: 8.5)
    complete(&drafts[1], weight: 170, reps: 4, rpe: 8)
    complete(&drafts[2], weight: 109, reps: 8, rpe: 8)
    let references = [
      fixture.squatExerciseID:
        ExerciseReference(
          last: nil,
          best: ExerciseReferenceSet(reps: 3, weightKg: 175)
        ),
      fixture.benchExerciseID:
        ExerciseReference(
          last: nil,
          best: ExerciseReferenceSet(reps: 5, weightKg: 110)
        ),
    ]

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: references,
      weekCode: "W1D4",
      coachName: nil
    )

    #expect(presentation.exercises[0].isPersonalRecord)
    #expect(!presentation.exercises[1].isPersonalRecord)
    #expect(presentation.hasPersonalRecord)
    #expect(presentation.personalRecordText == "深蹲 追平/刷新最佳纪录")
  }

  @Test func missingStreakStaysHiddenAtThePresentationBoundary() {
    let fixture = makeFixture()
    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: "   "
    )

    #expect(presentation.streak == nil)
    #expect(presentation.coachReceiptText == "教练已收到你的训练日志")
  }

  @Test(arguments: ["周教练", "演示教练"])
  func coachNameContainingRoleIsNotDuplicated(_ coachName: String) {
    let fixture = makeFixture()
    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: coachName
    )

    #expect(presentation.coachReceiptText == "\(coachName)已收到你的训练日志")
  }

  @Test func rpeUsesOneDecimalWithRoundHalfUpSemantics() {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 175, reps: 3, rpe: 8.2)
    complete(&drafts[1], weight: 170, reps: 3, rpe: 8.3)
    complete(&drafts[2], weight: 110, reps: 5, rpe: 8.25)

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: nil
    )

    #expect(presentation.mainRPEText == "8.3")
    #expect(presentation.averageRPEText == "8.3")
  }

  @Test func wholeNumberMainRPEDropsTheDecimalWhileAverageKeepsIt() {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 170, reps: 3, rpe: 8)
    complete(&drafts[1], weight: 170, reps: 3, rpe: 8)
    complete(&drafts[2], weight: 110, reps: 5, rpe: 8)

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: nil
    )

    #expect(presentation.mainRPEText == "8")
    #expect(presentation.averageRPEText == "8.0")
    #expect(presentation.metaText == "11 次 · 主项 RPE 8 · 符合计划")
  }

  @Test func fractionalSetsAveragingToAnExactWholeStillDropTheDecimal() {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    // 7.5/8.5 are exact in binary, so the Decimal average is exactly 8.
    complete(&drafts[0], weight: 170, reps: 3, rpe: 7.5)
    complete(&drafts[1], weight: 170, reps: 3, rpe: 8.5)
    complete(&drafts[2], weight: 110, reps: 5, rpe: 8)

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: nil
    )

    #expect(presentation.mainRPEText == "8")
  }

  @Test func fractionalMainRPEKeepsOneDecimalEvenWhenItRoundsToAWhole() {
    let fixture = makeFixture()
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 170, reps: 3, rpe: 8.9)
    complete(&drafts[1], weight: 170, reps: 3, rpe: 9)
    complete(&drafts[2], weight: 110, reps: 5, rpe: 8)

    let presentation = WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: nil
    )

    #expect(presentation.mainRPEText == "9.0")
  }

  @Test func planComparisonIncludesBoundariesAboveAndBelow() {
    let fixture = makeFixture()

    #expect(planComparison(fixture: fixture, actualRPE: 8.5) == "符合计划")
    #expect(planComparison(fixture: fixture, actualRPE: 7.5) == "符合计划")
    #expect(planComparison(fixture: fixture, actualRPE: 8.51) == "高于计划")
    #expect(planComparison(fixture: fixture, actualRPE: 7.49) == "低于计划")
  }

  private func makeFixture() -> Fixture {
    let squatExerciseID = UUID()
    let benchExerciseID = UUID()
    let squat = exercise(
      name: "深蹲",
      exerciseID: squatExerciseID,
      sets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 170, reps: 3, rpe: 8),
        PrescribedSet(id: UUID(), setIndex: 1, weightKg: 170, reps: 3, rpe: 8),
      ]
    )
    let bench = exercise(
      name: "卧推",
      exerciseID: benchExerciseID,
      sets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 110, reps: 5, rpe: 8)
      ]
    )
    let date =
      Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 24))
      ?? Date(timeIntervalSince1970: 0)
    let day = StudentPlanDay(id: UUID(), date: date, exercises: [squat, bench])
    return Fixture(
      day: day,
      drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
      squatExerciseID: squatExerciseID,
      benchExerciseID: benchExerciseID
    )
  }

  private func exercise(
    name: String,
    exerciseID: UUID,
    sets: [PrescribedSet]
  ) -> StudentPlanExercise {
    StudentPlanExercise(
      id: UUID(),
      exercise: Exercise(
        id: exerciseID,
        name: name,
        exerciseType: .mainLift,
        isCompetitionLift: true,
        muscleGroups: [],
        equipment: [],
        createdAt: Date(timeIntervalSince1970: 0)
      ),
      sequenceIndex: 0,
      prescribedSets: sets
    )
  }

  private func complete(
    _ draft: inout TodayWorkoutViewModel.SetRowDraft,
    weight: Decimal,
    reps: Int,
    rpe: Decimal,
    failed: Bool = false
  ) {
    draft.actualWeight = weight
    draft.actualReps = reps
    draft.actualRPE = rpe
    draft.completed = true
    draft.failed = failed
  }

  private func planComparison(fixture: Fixture, actualRPE: Decimal) -> String {
    var drafts = fixture.drafts
    complete(&drafts[0], weight: 170, reps: 3, rpe: actualRPE)
    complete(&drafts[1], weight: 170, reps: 3, rpe: actualRPE)
    return WorkoutCompletionPresentation(
      day: fixture.day,
      drafts: drafts,
      references: [:],
      weekCode: "W1D4",
      coachName: nil
    ).planComparisonText
  }
}
