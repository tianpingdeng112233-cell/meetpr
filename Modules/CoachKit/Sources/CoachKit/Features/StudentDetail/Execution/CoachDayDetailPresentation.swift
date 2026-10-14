import CoreModels
import Foundation
import Networking

struct CoachDayDetailPresentation: Sendable {
  struct Planned: Identifiable, Sendable {
    let exercise: StudentPlanExercise
    let prescribed: [CoachSetLogDTO]
    let extra: [CoachSetLogDTO]
    var id: UUID { exercise.id }
  }

  struct Added: Identifiable, Sendable {
    let id: UUID
    let exercise: Exercise?
    let logs: [CoachSetLogDTO]
  }

  let planned: [Planned]
  let added: [Added]

  init(day: StudentExecutionDay) {
    planned = (day.planDay?.exercises ?? []).map { exercise in
      let logs = day.allLogs.filter { $0.planExerciseID == exercise.id }
        .sorted { $0.setIndex < $1.setIndex }
      return Planned(
        exercise: exercise,
        prescribed: logs.filter { $0.setIndex >= 0 && $0.setIndex < exercise.prescribedSets.count },
        extra: logs.filter { $0.setIndex >= exercise.prescribedSets.count })
    }
    var grouped: [UUID: [CoachSetLogDTO]] = [:]
    var order: [UUID] = []
    for log in day.allLogs {
      guard log.adhoc, log.planExerciseID == nil, let owner = log.planDayID,
        owner == day.planDay?.id, let exerciseID = log.exerciseID
      else { continue }
      if grouped[exerciseID] == nil { order.append(exerciseID) }
      grouped[exerciseID, default: []].append(log)
    }
    added = order.map { id in
      Added(
        id: id, exercise: day.exerciseCatalog[id],
        logs: (grouped[id] ?? []).sorted { $0.setIndex < $1.setIndex })
    }
  }
}
