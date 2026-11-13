import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
struct AccessoryWeightHistoryIntegrationTests {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let student = UUID()

  func fixture() -> StudentPlanView {
    let exercise = Exercise(
      id: UUID(), name: "Row", exerciseType: .accessory, isCompetitionLift: false,
      muscleGroups: [], equipment: [], createdAt: now)
    let slot = StudentPlanExercise(
      id: UUID(), exercise: exercise, sequenceIndex: 0,
      prescribedSets: (0..<4).map {
        PrescribedSet(id: UUID(), setIndex: $0, reps: 12, rpe: 8)
      })
    let day = StudentPlanDay(id: UUID(), date: now, exercises: [slot])
    return StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  }

  func history(_ plan: StudentPlanView) -> [StudentSetLog] {
    let previousSlot = UUID()
    return [Decimal(20), 20, 17.5].enumerated().map { index, weight in
      StudentSetLog(
        id: UUID(), studentID: student, planExerciseID: previousSlot,
        exerciseID: plan.days[0].exercises[0].exercise.id, setIndex: index,
        loggedAt: now.addingTimeInterval(-120 * 86_400), weightKg: weight,
        reps: 10, rpe: 7, completed: true)
    }
  }

  @Test func loadsAcrossPlansBeyondTwelveWeeksWithoutMatchingRepsOrEffort() async throws {
    let plan = fixture()
    let history = history(plan)
    let logs = InMemoryStudentTrainingLogRepository(seed: history)
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: logs, now: { now })
    await model.load(dayID: plan.days[0].id, studentID: student)
    let rows = try #require(model.currentDrafts)
    #expect(rows.map(\.actualWeight) == [20, 20, 17.5, nil])
    #expect(rows.map(\.actualReps) == [12, 12, 12, 12])
    #expect(rows.map(\.actualRPE) == [8, 8, 8, 8])
    #expect(rows.allSatisfy { !$0.hasSavedRecord && !$0.completed })
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: rows[0], viewModel: model, field: .weight)
    keypad.dismiss()
    #expect(try await logs.fetchLogs(studentID: student, in: .distantPast...now).count == 3)
    #expect(model.currentDrafts?[0].isHistoryWeightPrefill == true)
    model.updateWeight(rowIndex: 0, weight: 22.5)
    #expect(model.currentDrafts?.map(\.actualWeight) == [22.5, 20, 17.5, nil])
    #expect(model.currentDrafts?[0].isHistoryWeightPrefill == false)
    #expect(await model.saveAllDayRow(rowIndex: 0))
    await model.load(dayID: plan.days[0].id, studentID: student)
    #expect(model.currentDrafts?.map(\.actualWeight) == [22.5, 20, 17.5, nil])
    #expect(model.currentDrafts?[0].hasSavedRecord == true)
    #expect(model.currentDrafts?[0].completed == false)
    model.updateWeight(rowIndex: 0, weight: nil)
    #expect(await model.saveAllDayRow(rowIndex: 0))
    await model.load(dayID: plan.days[0].id, studentID: student)
    #expect(model.currentDrafts?[0].actualWeight == nil)
    #expect(model.currentDrafts?[0].hasSavedRecord == true)
  }

  @Test func newestSessionDoesNotBorrowMissingGroupsAndIgnoresIneligibleLogs() throws {
    let plan = fixture()
    let day = plan.days[0]
    let slot = day.exercises[0]
    let previousSlot = UUID()
    func log(
      index: Int = 0, days: Double = -1, weight: Decimal? = 25,
      completed: Bool = true, failed: Bool = false, assumed: Bool = false,
      studentID: UUID? = nil, slotID: UUID? = nil
    ) -> StudentSetLog {
      StudentSetLog(
        id: UUID(), studentID: studentID ?? student, planExerciseID: slotID ?? previousSlot,
        exerciseID: slot.exercise.id, setIndex: index,
        loggedAt: now.addingTimeInterval(days * 86_400), weightKg: weight,
        reps: 12, completed: completed, failed: failed, assumed: assumed)
    }
    let candidates =
      history(plan) + [
        log(weight: nil), log(index: 1, weight: 0),
        log(days: 1, weight: 99), log(days: 0, completed: false),
        log(days: 0, failed: true), log(days: 0, assumed: true),
        log(days: 0, studentID: UUID()), log(days: 0, slotID: slot.id),
      ]
    let selected = AccessoryWeightHistory.previous(
      logs: candidates, day: day, studentID: student, now: now, planExerciseToExercise: [:])
    let rows = TodayWorkoutViewModel.makeDrafts(
      for: day, existingLogs: [], accessoryHistory: selected)
    #expect(rows.map(\.actualWeight) == [nil, 0, nil, nil])
    #expect(rows[1].isHistoryWeightPrefill == true)
  }
  @Test(arguments: [Decimal?(22.5), nil])
  func refreshedHistoryKeepsManualWeightAndClearedWeight(weight: Decimal?) async throws {
    let plan = fixture()
    let day = plan.days[0]
    let slot = day.exercises[0]
    let store = TestStudentPlanStore(seed: [student: plan])
    let logs = InMemoryStudentTrainingLogRepository(seed: history(plan))
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: store), logs: logs, now: { now })
    await model.load(dayID: day.id, studentID: student)
    #expect(model.currentDrafts?[0].actualWeight == 20)
    model.updateWeight(rowIndex: 0, weight: weight)
    let updatedSlot = StudentPlanExercise(
      id: slot.id, exercise: slot.exercise, sequenceIndex: 0,
      prescribedSets: slot.prescribedSets + [PrescribedSet(id: UUID(), setIndex: 4, reps: 12)])
    let updatedDay = StudentPlanDay(id: day.id, date: now, exercises: [updatedSlot])
    let updatedPlan = StudentPlanView(
      cycleID: plan.cycleID, weekIndex: 1, startDate: now, days: [updatedDay])
    await store.savePublishedProjection(updatedPlan, forStudent: student)
    try await logs.recordSet(
      StudentSetLog(
        id: UUID(), studentID: student, planExerciseID: UUID(), exerciseID: slot.exercise.id,
        setIndex: 0, loggedAt: now.addingTimeInterval(-86_400), weightKg: 60,
        reps: 10, completed: true))
    await model.refreshCurrentPlan(dayID: day.id, studentID: student)
    let rows = try #require(model.currentDrafts)
    #expect(rows.count == 5)
    #expect(rows[0].previousAccessoryWeight == 60)
    #expect(rows[0].actualWeight == weight)
    #expect(rows[0].isHistoryWeightPrefill == false)
    #expect(!rows[0].hasSavedRecord)
  }

}
