import CoreModels
import Foundation

public struct MuscleFatigueDTO: Codable, Equatable, Sendable {
  public let muscleGroup: String
  public let severity: Int

  public init(muscleGroup: String, severity: Int) {
    self.muscleGroup = muscleGroup
    self.severity = severity
  }
}

public struct SubmitReadinessRequestDTO: Encodable, Equatable, Sendable {
  public let checkinDate: String
  public let sleepQuality: Int
  public let mood: Int
  public let stress: Int
  public let muscleFatigue: [MuscleFatigueDTO]

  public init(
    checkinDate: String,
    sleepQuality: Int,
    mood: Int,
    stress: Int,
    muscleFatigue: [MuscleFatigueDTO]
  ) {
    self.checkinDate = checkinDate
    self.sleepQuality = sleepQuality
    self.mood = mood
    self.stress = stress
    self.muscleFatigue = muscleFatigue
  }
}

public struct ReadinessCheckinDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let checkinDate: String
  public let sleepQuality: Int
  public let mood: Int
  public let stress: Int
  public let muscleFatigue: [MuscleFatigueDTO]
  public let submittedAt: Date

  public func toDomain() -> ReadinessCheckin? {
    let fatigue = muscleFatigue.compactMap { dto -> MuscleFatigue? in
      guard let group = MuscleGroup(rawValue: dto.muscleGroup) else { return nil }
      return MuscleFatigue(muscleGroup: group, severity: dto.severity)
    }
    guard fatigue.count == muscleFatigue.count else { return nil }
    return ReadinessCheckin(
      id: id,
      studentId: studentId,
      checkinDate: checkinDate,
      sleepQuality: sleepQuality,
      mood: mood,
      stress: stress,
      muscleFatigue: fatigue,
      submittedAt: submittedAt
    )
  }
}

public struct ReadinessFetchResponseDTO: Codable, Equatable, Sendable {
  public let checkin: ReadinessCheckinDTO?

  public init(checkin: ReadinessCheckinDTO?) {
    self.checkin = checkin
  }
}
