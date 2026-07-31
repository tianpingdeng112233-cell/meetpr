import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func workoutKeepsLowRPEInDisplayButRequiresCalibrationForSuggestionBaseline() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = try suggestionPlan()
  let day = try #require(plan.days.first)
  let targetSetID = try #require(day.exercises.first?.prescribedSets.first?.id)
  let exerciseID = try #require(day.exercises.first?.exercise.id)
  let uncalibrated = suggestionPoint(
    studentId: studentID,
    exerciseId: exerciseID,
    computedAt: day.date.addingTimeInterval(-86_400),
    e1RMKg: 170
  )
  let uncalibratedViewModel = makeViewModel(
    studentID: studentID,
    plan: plan,
    point: uncalibrated
  )

  await uncalibratedViewModel.load(date: day.date, studentID: studentID)

  #expect(uncalibratedViewModel.exerciseReferences[exerciseID]?.best?.e1RMKg == 170)
  #expect(uncalibratedViewModel.weightSuggestion(forSetID: targetSetID) == nil)
  #expect(
    uncalibratedViewModel.weightSuggestionOutcome(forSetID: targetSetID).unavailableReason
      == .noEligibleE1RMHistory
  )

  let calibrated = suggestionPoint(
    studentId: studentID,
    exerciseId: exerciseID,
    computedAt: day.date.addingTimeInterval(-86_400),
    e1RMKg: 179.49,
    sourceCoachRPE: 8
  )
  let calibratedViewModel = makeViewModel(
    studentID: studentID,
    plan: plan,
    point: calibrated
  )

  await calibratedViewModel.load(date: day.date, studentID: studentID)

  #expect(calibratedViewModel.exerciseReferences[exerciseID]?.best?.e1RMKg == 179.49)
  let calibratedSuggestion = try #require(
    calibratedViewModel.weightSuggestion(forSetID: targetSetID)
  )
  #expect(calibratedSuggestion.basis == .e1RM(179.49))
  #expect(calibratedSuggestion.weightKg > 0)
  #expect(
    calibratedViewModel.weightSuggestionOutcome(forSetID: targetSetID).unavailableReason == nil
  )
}

private func suggestionPoint(
  studentId: UUID,
  exerciseId: UUID,
  computedAt: Date,
  e1RMKg: Double,
  sourceCoachRPE: Double? = nil
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentId,
    exerciseId: exerciseId,
    family: .squat,
    setLogId: UUID(),
    computedAt: computedAt,
    e1RMKg: e1RMKg,
    sourceWeightKg: 140,
    sourceReps: 5,
    sourceRPE: 6,
    sourceCoachRPE: sourceCoachRPE
  )
}

@MainActor
private func makeViewModel(
  studentID: UUID,
  plan: StudentPlanView,
  point: E1RMHistoryPoint
) -> TodayWorkoutViewModel {
  TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: InMemoryE1RMRepository(seedPoints: [point])
  )
}

private func suggestionPlan() throws -> StudentPlanView {
  let source = StudentDemoSeed.makePlanView()
  let sourceDay = try #require(source.days.first)
  let sourceExercise = try #require(sourceDay.exercises.first)
  let sourceSet = try #require(sourceExercise.prescribedSets.first)
  let targetSet = PrescribedSet(
    id: sourceSet.id,
    setIndex: sourceSet.setIndex,
    reps: sourceSet.reps,
    repsMax: sourceSet.repsMax,
    rpe: sourceSet.rpe,
    restSeconds: sourceSet.restSeconds,
    coachNote: sourceSet.coachNote
  )
  let exercise = StudentPlanExercise(
    id: sourceExercise.id,
    exercise: sourceExercise.exercise,
    sequenceIndex: sourceExercise.sequenceIndex,
    prescribedSets: [targetSet],
    notes: sourceExercise.notes
  )
  let day = StudentPlanDay(
    id: sourceDay.id,
    date: sourceDay.scheduledDate,
    shiftedToDate: sourceDay.shiftedToDate,
    exercises: [exercise]
  )
  return StudentPlanView(
    cycleID: source.cycleID,
    weekIndex: source.weekIndex,
    startDate: day.date,
    endDate: day.date,
    planKind: source.planKind,
    totalShiftDays: source.totalShiftDays,
    latestShiftCreatedAt: source.latestShiftCreatedAt,
    days: [day]
  )
}
