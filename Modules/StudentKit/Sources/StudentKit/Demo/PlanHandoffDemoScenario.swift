import CoreModels
import Foundation
import RepositoryContracts

/// Opt-in layout fixtures. Never used by the authenticated backend repositories.
public enum PlanHandoffDemoScenario {
  public static var enabled: Bool {
    ProcessInfo.processInfo.arguments.contains("--plan-handoff-demo")
  }

  public static func repository() -> (any StudentPlanRepository)? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "--plan-handoff-demo"),
      arguments.indices.contains(index + 1)
    else { return nil }
    let joined = arguments[index + 1] == "joined"
    let seed = StudentDemoSeed.makePlanView()
    let nextID = UUID(uuid: (110, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    let handoff = StudentPlanHandoff(
      currentPlanID: joined ? nextID : seed.cycleID,
      plans: [
        .init(
          id: seed.cycleID, name: "10.19 计划", weeks: 5,
          completedTrainingDays: joined ? 8 : 4, totalTrainingDays: 8,
          status: joined ? .past : .current),
        .init(
          id: nextID, name: "11.23 计划", weeks: 12,
          completedTrainingDays: 0, totalTrainingDays: 4, status: joined ? .current : .upcoming),
      ])
    let oldDays = seed.days.enumerated().map { offset, day in
      StudentPlanDay(
        id: day.id, weekNumber: offset / 4 + 4, dayOfWeek: offset % 4 + 1,
        sortOrder: offset, date: day.date, completedAt: joined || offset < 4 ? day.date : nil,
        completionSource: joined || offset < 4 ? "manual" : nil, exercises: day.exercises)
    }
    let old = StudentPlanView(
      cycleID: seed.cycleID, handoff: handoff, weekIndex: 5,
      startDate: seed.startDate, endDate: seed.endDate, days: oldDays)
    let nextDays = seed.days.prefix(4).enumerated().map { offset, day in
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: offset + 1, sortOrder: offset,
        date: day.date.addingTimeInterval(14 * 86400),
        exercises: day.exercises.map {
          StudentPlanExercise(
            id: UUID(), exercise: $0.exercise, sequenceIndex: $0.sequenceIndex,
            prescribedSets: $0.prescribedSets, notes: $0.notes)
        })
    }
    let next = StudentPlanView(
      cycleID: nextID, handoff: handoff, weekIndex: 1,
      startDate: seed.startDate.addingTimeInterval(14 * 86400), days: nextDays)
    return PlanHandoffDemoRepository(current: joined ? next : old, plans: [old, next])
  }
}

private struct PlanHandoffDemoRepository: StudentPlanRepository {
  let current: StudentPlanView
  let plans: [StudentPlanView]
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { current }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { current.days }
  func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    plans.first { $0.cycleID == id }
  }
}
