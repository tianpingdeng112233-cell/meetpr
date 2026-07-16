import Foundation
import Testing

@testable import CoreModels

private let utc: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  return calendar
}()
private let base = Date(timeIntervalSince1970: 1_777_248_000)  // midnight UTC
private func day(_ offset: Int) -> Date { base.addingTimeInterval(Double(offset) * 86_400) }
private let studentID = UUID()

private func exercise() -> Exercise {
  Exercise(
    id: UUID(), name: "x", exerciseType: .mainLift, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: base)
}

private func planDay(date: Date, exerciseSetCounts: [Int]) -> StudentPlanDay {
  let exercises = exerciseSetCounts.enumerated().map { index, setCount in
    StudentPlanExercise(
      id: UUID(), exercise: exercise(), sequenceIndex: index,
      prescribedSets: (0..<setCount).map { PrescribedSet(id: UUID(), setIndex: $0) })
  }
  return StudentPlanDay(id: UUID(), date: date, exercises: exercises)
}

private func log(
  planExerciseID: UUID,
  at date: Date,
  completed: Bool = true,
  assumed: Bool = false
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(), studentID: studentID, planExerciseID: planExerciseID, setIndex: 0,
    loggedAt: date, weightKg: 100, reps: 5, completed: completed, assumed: assumed)
}

@Test func completionAggregatesTwoCycleAlignedWeeks() {
  let w1d1 = planDay(date: day(0), exerciseSetCounts: [3])
  let w1d2 = planDay(date: day(2), exerciseSetCounts: [3])
  let w2d1 = planDay(date: day(7), exerciseSetCounts: [4])
  let plan = [w1d1, w1d2, w2d1]
  let logs =
    (0..<3).map { _ in log(planExerciseID: w1d1.exercises[0].id, at: day(0)) }
    + [log(planExerciseID: w1d2.exercises[0].id, at: day(2))]

  let weeks = CompletionHistory.weekly(planDays: plan, logs: logs, calendar: utc)
  #expect(weeks.count == 2)

  let week1 = weeks[0]
  #expect(week1.weekIndex == 0)
  #expect(week1.weekStart == utc.startOfDay(for: day(0)))
  #expect(week1.plannedTrainingDays == 2)
  #expect(week1.completedTrainingDays == 2)
  #expect(week1.plannedSets == 6)
  #expect(week1.completedSets == 4)

  let week2 = weeks[1]
  #expect(week2.weekIndex == 1)
  #expect(week2.plannedTrainingDays == 1)
  #expect(week2.completedTrainingDays == 0)
  #expect(week2.plannedSets == 4)
  #expect(week2.completedSets == 0)
}

@Test func completionRestDaysExcludedFromDenominator() {
  let training = planDay(date: day(0), exerciseSetCounts: [2])
  let rest = planDay(date: day(1), exerciseSetCounts: [])
  let weeks = CompletionHistory.weekly(planDays: [training, rest], logs: [], calendar: utc)
  #expect(weeks.count == 1)
  #expect(weeks[0].plannedTrainingDays == 1)
  #expect(weeks[0].plannedSets == 2)
}

@Test func completionAttributedByPlanExerciseNotLogDate() {
  let dayPlan = planDay(date: day(0), exerciseSetCounts: [2])
  // Logged a day late (day 1) but belongs to day 0's plan exercise.
  let weeks = CompletionHistory.weekly(
    planDays: [dayPlan],
    logs: [log(planExerciseID: dayPlan.exercises[0].id, at: day(1))],
    calendar: utc)
  #expect(weeks.count == 1)
  #expect(weeks[0].completedTrainingDays == 1)
  #expect(weeks[0].completedSets == 1)
}

@Test func completionIncompleteAndUnmappedLogsIgnored() {
  let dayPlan = planDay(date: day(0), exerciseSetCounts: [3])
  let logs = [
    log(planExerciseID: dayPlan.exercises[0].id, at: day(0), completed: false),
    log(planExerciseID: UUID(), at: day(0)),
  ]
  let weeks = CompletionHistory.weekly(planDays: [dayPlan], logs: logs, calendar: utc)
  #expect(weeks.count == 1)
  #expect(weeks[0].completedSets == 0)
  #expect(weeks[0].completedTrainingDays == 0)
}

@Test func completionAssumedLogsExcludedFromSetsAndTrainingDays() {
  let dayPlan = planDay(date: day(0), exerciseSetCounts: [2])
  let weeks = CompletionHistory.weekly(
    planDays: [dayPlan],
    logs: [
      log(planExerciseID: dayPlan.exercises[0].id, at: day(0), assumed: true)
    ],
    calendar: utc)

  #expect(weeks.count == 1)
  #expect(weeks[0].completedSets == 0)
  #expect(weeks[0].completedTrainingDays == 0)
}

@Test func completionEmptyPlanReturnsNoWeeks() {
  #expect(CompletionHistory.weekly(planDays: [], logs: [], calendar: utc).isEmpty)
}

@Test func completionRatesComputed() {
  let dayOne = planDay(date: day(0), exerciseSetCounts: [4])
  let dayTwo = planDay(date: day(2), exerciseSetCounts: [4])
  let logs = (0..<2).map { _ in log(planExerciseID: dayOne.exercises[0].id, at: day(0)) }
  let week = CompletionHistory.weekly(planDays: [dayOne, dayTwo], logs: logs, calendar: utc)[0]
  #expect(week.plannedTrainingDays == 2)
  #expect(week.completedTrainingDays == 1)
  #expect(abs(week.dayCompletionRate - 0.5) < 1e-9)
  #expect(week.plannedSets == 8)
  #expect(week.completedSets == 2)
  #expect(abs(week.setCompletionRate - 0.25) < 1e-9)
}
