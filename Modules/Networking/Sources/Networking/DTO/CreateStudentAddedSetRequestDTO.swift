import CoreModels
import Foundation

public struct CreateStudentAddedSetRequestDTO: Encodable, Sendable {
  public let log: StudentAddedSetLog

  public init(log: StudentAddedSetLog) { self.log = log }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Keys.self)
    try container.encodeIfPresent(log.planDayID, forKey: .planDayID)
    try container.encode(log.exerciseID, forKey: .exerciseID)
    try container.encode(log.setIndex, forKey: .setIndex)
    try container.encodeDecimalString(log.weightKg, forKey: .weightKg)
    try container.encode(log.reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(log.rpe, forKey: .rpe)
    try container.encode(log.completed, forKey: .completed)
    try container.encode(log.failed, forKey: .failed)
    try container.encode(log.loggedDate, forKey: .loggedDate)
  }

  private enum Keys: String, CodingKey {
    case planDayID = "planDayId"
    case exerciseID = "exerciseId"
    case setIndex, weightKg, reps, rpe, completed, failed, loggedDate
  }
}
