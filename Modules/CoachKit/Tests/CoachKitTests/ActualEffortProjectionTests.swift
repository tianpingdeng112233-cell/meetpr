import CoreModels
import Foundation
import Networking
import Testing

@testable import CoachKit

@Test(arguments: [0, 2]) func plannedCoachProjectionKeepsActualRIR(_ rir: Int) throws {
  let log = StudentSetLog(
    id: UUID(), studentID: UUID(), planExerciseID: UUID(), setIndex: 0, loggedAt: Date(),
    weightKg: 0, reps: 10, actualRIR: rir, completed: true)
  let projected = try #require(CoachSetLogDTO(log).plannedLog)
  #expect(projected.actualRIR == rir && projected.rpe == nil)
}
