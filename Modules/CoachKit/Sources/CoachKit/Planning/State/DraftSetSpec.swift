import CoreModels
import Foundation

public struct DraftSetTarget: Codable, Hashable, Sendable {
  public var targetReps: Int
  public var targetRepsMax: Int?
  public var intensityMode: IntensityMode
  public var targetValue: Decimal
  public var setType: SetType

  public init(
    targetReps: Int,
    targetRepsMax: Int? = nil,
    intensityMode: IntensityMode,
    targetValue: Decimal,
    setType: SetType = .working
  ) {
    self.targetReps = targetReps
    self.targetRepsMax = targetRepsMax
    self.intensityMode = intensityMode
    self.targetValue = targetValue
    self.setType = setType
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    targetReps = try container.decode(Int.self, forKey: .targetReps)
    targetRepsMax = try container.decodeIfPresent(Int.self, forKey: .targetRepsMax)
    intensityMode = try container.decode(IntensityMode.self, forKey: .intensityMode)
    targetValue = try container.decodeDecimalString(forKey: .targetValue)
    setType = try container.decode(SetType.self, forKey: .setType)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(targetReps, forKey: .targetReps)
    try container.encodeIfPresent(targetRepsMax, forKey: .targetRepsMax)
    try container.encode(intensityMode, forKey: .intensityMode)
    try container.encodeDecimalString(targetValue, forKey: .targetValue)
    try container.encode(setType, forKey: .setType)
  }

  private enum CodingKeys: String, CodingKey {
    case targetReps
    case targetRepsMax
    case intensityMode
    case targetValue
    case setType
  }
}

public struct DraftSetSpec: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public var setCount: Int
  public var targetReps: Int
  public var targetRepsMax: Int?
  public var intensityMode: IntensityMode
  public var targetValue: Decimal
  public var setType: SetType
  public var restSeconds: Int?
  public var restSecondsPerSet: [Int]?
  public var perSetTargets: [DraftSetTarget]?
  public var notes: String?

  public init(
    id: UUID = UUID(),
    setCount: Int,
    targetReps: Int,
    targetRepsMax: Int? = nil,
    intensityMode: IntensityMode,
    targetValue: Decimal,
    setType: SetType = .working,
    restSeconds: Int? = nil,
    restSecondsPerSet: [Int]? = nil,
    perSetTargets: [DraftSetTarget]? = nil,
    notes: String? = nil
  ) {
    self.id = id
    self.setCount = setCount
    self.targetReps = targetReps
    self.targetRepsMax = targetRepsMax
    self.intensityMode = intensityMode
    self.targetValue = targetValue
    self.setType = setType
    self.restSeconds = restSeconds
    self.restSecondsPerSet = restSecondsPerSet
    self.perSetTargets = perSetTargets
    self.notes = notes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    setCount = try container.decode(Int.self, forKey: .setCount)
    targetReps = try container.decode(Int.self, forKey: .targetReps)
    targetRepsMax = try container.decodeIfPresent(Int.self, forKey: .targetRepsMax)
    intensityMode = try container.decode(IntensityMode.self, forKey: .intensityMode)
    targetValue = try container.decodeDecimalString(forKey: .targetValue)
    setType = try container.decode(SetType.self, forKey: .setType)
    restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
    restSecondsPerSet = try container.decodeIfPresent([Int].self, forKey: .restSecondsPerSet)
    perSetTargets = try container.decodeIfPresent([DraftSetTarget].self, forKey: .perSetTargets)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(setCount, forKey: .setCount)
    try container.encode(targetReps, forKey: .targetReps)
    try container.encodeIfPresent(targetRepsMax, forKey: .targetRepsMax)
    try container.encode(intensityMode, forKey: .intensityMode)
    try container.encodeDecimalString(targetValue, forKey: .targetValue)
    try container.encode(setType, forKey: .setType)
    try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    try container.encodeIfPresent(restSecondsPerSet, forKey: .restSecondsPerSet)
    try container.encodeIfPresent(perSetTargets, forKey: .perSetTargets)
    try container.encodeIfPresent(notes, forKey: .notes)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case setCount
    case targetReps
    case targetRepsMax
    case intensityMode
    case targetValue
    case setType
    case restSeconds
    case restSecondsPerSet
    case perSetTargets
    case notes
  }
}

extension DraftSetSpec {
  public var baseTarget: DraftSetTarget {
    DraftSetTarget(
      targetReps: targetReps,
      targetRepsMax: targetRepsMax,
      intensityMode: intensityMode,
      targetValue: targetValue,
      setType: setType
    )
  }

  public func target(forSetNumber setNumber: Int) -> DraftSetTarget {
    let index = max(0, setNumber - 1)
    if let perSetTargets, perSetTargets.indices.contains(index) {
      return perSetTargets[index]
    }
    return baseTarget
  }
}

extension KeyedDecodingContainer {
  func decodeDecimalString(forKey key: Key) throws -> Decimal {
    if let stringValue = try? decode(String.self, forKey: key) {
      guard let decimal = Decimal(string: stringValue) else {
        throw DecodingError.dataCorruptedError(
          forKey: key,
          in: self,
          debugDescription: "Expected Decimal string for \(key.stringValue)"
        )
      }

      return decimal
    }

    return try decode(Decimal.self, forKey: key)
  }
}

extension KeyedEncodingContainer {
  mutating func encodeDecimalString(_ decimal: Decimal, forKey key: Key) throws {
    try encode(NSDecimalNumber(decimal: decimal).stringValue, forKey: key)
  }
}
