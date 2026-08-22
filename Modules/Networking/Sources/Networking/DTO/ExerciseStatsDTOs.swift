import Foundation

public struct CoachExerciseStatsResponseDTO: Codable, Equatable, Sendable {
  public let e1RM: ExerciseStatsE1RMDTO?
  public let e1RMSeries: ExerciseStatsE1RMSeriesDTO?
  public let oneRM: ExerciseStatsOneRMDTO

  public init(
    e1RM: ExerciseStatsE1RMDTO? = nil,
    e1RMSeries: ExerciseStatsE1RMSeriesDTO? = nil,
    oneRM: ExerciseStatsOneRMDTO
  ) {
    self.e1RM = e1RM
    self.e1RMSeries = e1RMSeries
    self.oneRM = oneRM
  }

  private enum CodingKeys: String, CodingKey {
    case e1RM = "e1rm"
    case e1RMSeries = "e1rmSeries"
    case oneRM = "oneRm"
  }
}

public struct ExerciseStatsE1RMDTO: Codable, Equatable, Sendable {
  public let squat: ExerciseStatsE1RMValueDTO?
  public let bench: ExerciseStatsE1RMValueDTO?
  public let deadlift: ExerciseStatsE1RMValueDTO?

  public init(
    squat: ExerciseStatsE1RMValueDTO? = nil,
    bench: ExerciseStatsE1RMValueDTO? = nil,
    deadlift: ExerciseStatsE1RMValueDTO? = nil
  ) {
    self.squat = squat
    self.bench = bench
    self.deadlift = deadlift
  }
}

/// Only the rolling value is consumed by iOS. `computed_at` and any future
/// overview fields are deliberately ignored by Codable.
public struct ExerciseStatsE1RMValueDTO: Codable, Equatable, Sendable {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

public struct ExerciseStatsE1RMSeriesDTO: Codable, Equatable, Sendable {
  public let squat: ExerciseStatsE1RMFamilySeriesDTO
  public let bench: ExerciseStatsE1RMFamilySeriesDTO
  public let deadlift: ExerciseStatsE1RMFamilySeriesDTO

  public init(
    squat: ExerciseStatsE1RMFamilySeriesDTO,
    bench: ExerciseStatsE1RMFamilySeriesDTO,
    deadlift: ExerciseStatsE1RMFamilySeriesDTO
  ) {
    self.squat = squat
    self.bench = bench
    self.deadlift = deadlift
  }
}

public struct ExerciseStatsE1RMFamilySeriesDTO: Codable, Equatable, Sendable {
  public let points: [ExerciseStatsE1RMPointDTO]
  public let trend: ExerciseStatsE1RMTrendDTO

  public init(
    points: [ExerciseStatsE1RMPointDTO],
    trend: ExerciseStatsE1RMTrendDTO
  ) {
    self.points = points
    self.trend = trend
  }
}

public struct ExerciseStatsE1RMPointDTO: Codable, Equatable, Sendable {
  public let date: String
  public let value: String

  public init(date: String, value: String) {
    self.date = date
    self.value = value
  }
}

public enum ExerciseStatsE1RMTrendDTO: Codable, Equatable, Sendable {
  case upward
  case steady
  case downward
  case new
  case unknown(String)

  public init(from decoder: any Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self =
      switch rawValue {
      case "up": .upward
      case "flat": .steady
      case "down": .downward
      case "new": .new
      default: .unknown(rawValue)
      }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    let rawValue =
      switch self {
      case .upward: "up"
      case .steady: "flat"
      case .downward: "down"
      case .new: "new"
      case .unknown(let value): value
      }
    try container.encode(rawValue)
  }
}

public struct ExerciseStatsOneRMDTO: Codable, Equatable, Sendable {
  public let squat: String?
  public let bench: String?
  public let deadlift: String?

  public init(
    squat: String? = nil,
    bench: String? = nil,
    deadlift: String? = nil
  ) {
    self.squat = squat
    self.bench = bench
    self.deadlift = deadlift
  }
}
