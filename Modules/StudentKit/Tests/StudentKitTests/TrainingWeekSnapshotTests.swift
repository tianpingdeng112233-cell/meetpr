import CoreModels
import Foundation
import Testing

@testable import StudentKit

// Spec 049 §1: completion has one source of truth. The same snapshot must
// answer the today card, the week bar and the calendar dots identically.

private let student = UUID()
private let planExerciseID = UUID()
private let exerciseID = UUID()

private func day(date: Date, sets: Int) -> StudentPlanDay {
  StudentPlanDay(
    id: UUID(),
    date: date,
    exercises: [
      StudentPlanExercise(
        id: planExerciseID,
        exercise: Exercise(
          id: exerciseID,
          name: "低杠位深蹲",
          exerciseType: .mainLift,
          mainLiftFamily: .squat,
          isCompetitionLift: true,
          muscleGroups: [.quad],
          equipment: [.barbell],
          createdAt: Date(timeIntervalSince1970: 0)
        ),
        sequenceIndex: 0,
        prescribedSets: (0..<sets).map { index in
          PrescribedSet(id: UUID(), setIndex: index, weightKg: 140, reps: 5, rpe: 8)
        }
      )
    ]
  )
}

private func completedLog(setIndex: Int, at date: Date) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: student,
    planExerciseID: planExerciseID,
    exerciseID: exerciseID,
    setIndex: setIndex,
    loggedAt: date,
    weightKg: 140,
    reps: 5,
    rpe: 8,
    completed: true
  )
}

private let trainingDate = Date(timeIntervalSince1970: 1_782_000_000)

@available(iOS 17.0, macOS 14.0, *)
@Test func allSetsCompletedReachesCompleteEverywhere() {
  let planDay = day(date: trainingDate, sets: 3)
  let snapshot = TrainingWeekSnapshot(
    days: [planDay],
    logs: (0..<3).map { completedLog(setIndex: $0, at: trainingDate) }
  )

  // Today card, calendar dot and week bar all read the same answer.
  #expect(snapshot.progress(on: trainingDate).state == .complete)
  #expect(snapshot.progress(for: planDay).state == .complete)
  #expect(snapshot.weekSegments() == [1.0])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func partialCompletionStaysConsistentAcrossConsumers() {
  let planDay = day(date: trainingDate, sets: 3)
  let snapshot = TrainingWeekSnapshot(
    days: [planDay],
    logs: [completedLog(setIndex: 0, at: trainingDate)]
  )

  #expect(snapshot.progress(on: trainingDate).state == .partial)
  #expect(snapshot.progress(for: planDay).state == .partial)
  #expect(snapshot.weekSegments().first.map { abs($0 - 1.0 / 3.0) < 0.0001 } == true)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func calendarDaysDeriveFromTheSameSnapshot() {
  let planDay = day(date: trainingDate, sets: 2)
  let logs = (0..<2).map { completedLog(setIndex: $0, at: trainingDate) }
  let snapshot = TrainingWeekSnapshot(days: [planDay], logs: logs)

  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
  let period = TrainingCalendarPeriod(
    displayedDate: trainingDate, selectedDate: trainingDate, today: trainingDate, mode: .week)
  let calendarDays = TrainingCalendarLayout.makeDays(
    period: period, snapshot: snapshot, calendar: calendar)

  let trained = calendarDays.first { $0.planDay != nil }
  #expect(trained?.progress.state == .complete)
  #expect(trained?.progress == snapshot.progress(on: trainingDate, calendar: calendar))
}
