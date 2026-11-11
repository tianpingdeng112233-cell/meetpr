import Foundation

/// An action-level note; no set snapshot or video is attached.
public struct ExerciseRefV1: Codable, Hashable, Sendable {
  public let version: Int
  public let exerciseName: String
  public let dayDate: String
  public let planDayID: UUID?
  public let planExerciseID: UUID?
  public let exerciseID: UUID

  public init(
    exerciseName: String, dayDate: String, planDayID: UUID?,
    planExerciseID: UUID?, exerciseID: UUID
  ) {
    version = 1
    self.exerciseName = exerciseName
    self.dayDate = dayDate
    self.planDayID = planDayID
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
  }

  public var shortDate: String {
    let parts = dayDate.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return dayDate }
    return "\(parts[1])/\(parts[2])"
  }

  public func body(note: String, english: Bool) -> String {
    let prefix = english ? "[Exercise note]" : "[动作留言]"
    return "\(prefix) \(exerciseName) · \(shortDate)\n\(note)"
  }

  public func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(version, forKey: .version)
    try values.encode(exerciseName, forKey: .exerciseName)
    try values.encode(dayDate, forKey: .dayDate)
    try values.encode(planDayID, forKey: .planDayID)
    try values.encode(planExerciseID, forKey: .planExerciseID)
    try values.encode(exerciseID, forKey: .exerciseID)
  }

  private enum CodingKeys: String, CodingKey {
    case version = "v"
    case exerciseName, dayDate
    case planDayID = "planDayId"
    case planExerciseID = "planExerciseId"
    case exerciseID = "exerciseId"
  }
}
