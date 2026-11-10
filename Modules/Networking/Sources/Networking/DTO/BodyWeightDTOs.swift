import Foundation

public struct BodyWeightRecordDTO: Decodable, Equatable, Sendable {
  public let recordedOn: String
  public let weightKg: Decimal

  enum CodingKeys: String, CodingKey {
    case recordedOn, weightKg
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    recordedOn = try container.decode(String.self, forKey: .recordedOn)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
  }
}

public struct BodyWeightRecordsDTO: Decodable, Sendable {
  public let records: [BodyWeightRecordDTO]
}

public struct BodyWeightWriteDTO: Decodable, Sendable {
  public let record: BodyWeightRecordDTO
  public let currentWeightKg: Decimal?

  enum CodingKeys: String, CodingKey { case record, currentWeightKg }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    record = try container.decode(BodyWeightRecordDTO.self, forKey: .record)
    currentWeightKg = try container.decodeDecimalIfPresent(forKey: .currentWeightKg)
  }
}

public struct BodyWeightDeleteDTO: Decodable, Sendable {
  public let currentWeightKg: Decimal?

  enum CodingKeys: String, CodingKey { case currentWeightKg }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    currentWeightKg = try container.decodeDecimalIfPresent(forKey: .currentWeightKg)
  }
}
