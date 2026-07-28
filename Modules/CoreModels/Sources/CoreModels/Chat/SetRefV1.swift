import Foundation

public enum SetRefValidationError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case invalidExerciseName
  case invalidSetNumber(Int)
  case invalidWeight(String)
  case invalidReps(Int)
  case invalidRPE(String)
  case invalidDayDate(String)
  case missingField(String)
  case unknownFields([String])
}

public struct SetRefSourceSnapshot: Sendable {
  public let exerciseName: String
  public let setNumber: Int
  public let weightKg: String?
  public let reps: Int?
  public let rpe: String?
  public let dayDate: String
  public let setLogId: UUID

  public init(
    exerciseName: String,
    setNumber: Int,
    weightKg: String?,
    reps: Int?,
    rpe: String?,
    dayDate: String,
    setLogId: UUID
  ) {
    self.exerciseName = exerciseName
    self.setNumber = setNumber
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.dayDate = dayDate
    self.setLogId = setLogId
  }
}

/// Frozen, canonical snapshot of one completed training set shared through chat.
///
/// Decimal values stay as strings at the wire boundary. Construction from source
/// wire values parses them into integer minor units before producing the canonical
/// strings held by this value.
public struct SetRefV1: Codable, Hashable, Sendable {
  public let version: Int
  public let exerciseName: String
  public let setNumber: Int
  public let weightKg: String?
  public let reps: Int?
  public let rpe: String?
  public let dayDate: String
  public let setLogId: UUID

  public init(
    version: Int = 1,
    exerciseName: String,
    setNumber: Int,
    weightKg: String?,
    reps: Int?,
    rpe: String?,
    dayDate: String,
    setLogId: UUID
  ) throws {
    try Self.validateVersion(version)
    try Self.validateExerciseName(exerciseName)
    try Self.validateSetNumber(setNumber)
    try weightKg.map(Self.validateCanonicalWeight)
    try reps.map(Self.validateReps)
    try rpe.map(Self.validateCanonicalRPE)
    try Self.validateDayDate(dayDate)

    self.version = version
    self.exerciseName = exerciseName
    self.setNumber = setNumber
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.dayDate = dayDate
    self.setLogId = setLogId
  }

  /// Builds a canonical snapshot from fixed-precision source wire strings.
  ///
  /// Examples: `"100.00"` becomes `"100"` and `"8.0"` becomes `"8"`.
  /// Parsing is digit-by-digit; no binary floating-point value is created.
  public static func normalizingSource(_ source: SetRefSourceSnapshot) throws -> SetRefV1 {
    let normalizedWeight = try source.weightKg.map(normalizeWeight)
    let normalizedRPE = try source.rpe.map(normalizeRPE)
    return try SetRefV1(
      exerciseName: source.exerciseName,
      setNumber: source.setNumber,
      weightKg: normalizedWeight,
      reps: source.reps,
      rpe: normalizedRPE,
      dayDate: source.dayDate,
      setLogId: source.setLogId
    )
  }

  public init(from decoder: any Decoder) throws {
    let allKeys = try decoder.container(keyedBy: SetRefAnyCodingKey.self)
    let allowedKeys = Set(CodingKeys.allCases.map(\.stringValue))
    let unknownKeys = allKeys.allKeys.map(\.stringValue).filter { !allowedKeys.contains($0) }
      .sorted()
    guard unknownKeys.isEmpty else {
      throw SetRefValidationError.unknownFields(unknownKeys)
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    for key in CodingKeys.allCases where !container.contains(key) {
      throw SetRefValidationError.missingField(key.stringValue)
    }

    try self.init(
      version: container.decode(Int.self, forKey: .version),
      exerciseName: container.decode(String.self, forKey: .exerciseName),
      setNumber: container.decode(Int.self, forKey: .setNumber),
      weightKg: container.decodeIfPresent(String.self, forKey: .weightKg),
      reps: container.decodeIfPresent(Int.self, forKey: .reps),
      rpe: container.decodeIfPresent(String.self, forKey: .rpe),
      dayDate: container.decode(String.self, forKey: .dayDate),
      setLogId: container.decode(UUID.self, forKey: .setLogId)
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(exerciseName, forKey: .exerciseName)
    try container.encode(setNumber, forKey: .setNumber)
    try container.encode(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encode(rpe, forKey: .rpe)
    try container.encode(dayDate, forKey: .dayDate)
    try container.encode(setLogId, forKey: .setLogId)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case version = "v"
    case exerciseName
    case setNumber
    case weightKg
    case reps
    case rpe
    case dayDate
    case setLogId
  }
}

public enum SetRefCanonicalFormatter {
  public static func firstLine(for setRef: SetRefV1) -> String {
    let weight = setRef.weightKg.map { "\($0)kg" } ?? "-kg"
    let reps = setRef.reps.map(String.init) ?? "-"
    let rpe = setRef.rpe.map { " @RPE\($0)" } ?? ""
    return
      "[训练分享] \(setRef.exerciseName) 第\(setRef.setNumber)组 "
      + "\(weight)×\(reps)\(rpe) (\(setRef.dayDate))"
  }

  public static func body(for setRef: SetRefV1, note: String?) -> String {
    let firstLine = firstLine(for: setRef)
    guard let note, !note.isEmpty else {
      return firstLine
    }
    return "\(firstLine)\n\(note)"
  }
}

extension SetRefV1 {
  private static let maximumSetNumber = 2_147_483_648
  private static let maximumWeightMinorUnits = 999_999

  private static func validateVersion(_ value: Int) throws {
    guard value == 1 else {
      throw SetRefValidationError.unsupportedVersion(value)
    }
  }

  private static func validateExerciseName(_ value: String) throws {
    guard !value.isEmpty,
      value.unicodeScalars.count <= 120,
      !value.unicodeScalars.contains(where: {
        $0.properties.generalCategory == .control || $0.value == 0x2028 || $0.value == 0x2029
      })
    else {
      throw SetRefValidationError.invalidExerciseName
    }
  }

  private static func validateSetNumber(_ value: Int) throws {
    guard (1...maximumSetNumber).contains(value) else {
      throw SetRefValidationError.invalidSetNumber(value)
    }
  }

  private static func validateCanonicalWeight(_ value: String) throws {
    guard try normalizeWeight(value) == value else {
      throw SetRefValidationError.invalidWeight(value)
    }
  }

  private static func validateReps(_ value: Int) throws {
    guard (0...99).contains(value) else {
      throw SetRefValidationError.invalidReps(value)
    }
  }

  private static func validateCanonicalRPE(_ value: String) throws {
    guard try normalizeRPE(value) == value else {
      throw SetRefValidationError.invalidRPE(value)
    }
  }

  private static func validateDayDate(_ value: String) throws {
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard value.utf8.count == 10,
      parts.count == 3,
      parts[0].count == 4,
      parts[1].count == 2,
      parts[2].count == 2,
      parts.allSatisfy({ $0.utf8.allSatisfy(isASCIIDigit) }),
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2]),
      let timeZone = TimeZone(secondsFromGMT: 0)
    else {
      throw SetRefValidationError.invalidDayDate(value)
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = DateComponents(
      calendar: calendar,
      timeZone: timeZone,
      year: year,
      month: month,
      day: day
    )
    guard let date = calendar.date(from: components) else {
      throw SetRefValidationError.invalidDayDate(value)
    }
    let resolved = calendar.dateComponents([.year, .month, .day], from: date)
    guard resolved.year == year, resolved.month == month, resolved.day == day else {
      throw SetRefValidationError.invalidDayDate(value)
    }
  }

  private static func normalizeWeight(_ value: String) throws -> String {
    do {
      let minorUnits = try parseMinorUnits(value, fractionalPlaces: 2, maximumIntegerDigits: 4)
      guard minorUnits <= maximumWeightMinorUnits else {
        throw SetRefValidationError.invalidWeight(value)
      }
      return canonicalDecimal(minorUnits: minorUnits, fractionalPlaces: 2)
    } catch is SetRefValidationError {
      throw SetRefValidationError.invalidWeight(value)
    } catch {
      throw SetRefValidationError.invalidWeight(value)
    }
  }

  private static func normalizeRPE(_ value: String) throws -> String {
    do {
      let minorUnits = try parseMinorUnits(value, fractionalPlaces: 1, maximumIntegerDigits: 2)
      guard minorUnits <= 100, minorUnits.isMultiple(of: 5) else {
        throw SetRefValidationError.invalidRPE(value)
      }
      return canonicalDecimal(minorUnits: minorUnits, fractionalPlaces: 1)
    } catch is SetRefValidationError {
      throw SetRefValidationError.invalidRPE(value)
    } catch {
      throw SetRefValidationError.invalidRPE(value)
    }
  }

  private static func parseMinorUnits(
    _ value: String,
    fractionalPlaces: Int,
    maximumIntegerDigits: Int
  ) throws -> Int {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...2).contains(parts.count) else {
      throw SetRefValidationError.invalidWeight(value)
    }

    let integerPart = parts[0]
    guard !integerPart.isEmpty,
      integerPart.count <= maximumIntegerDigits,
      integerPart.utf8.allSatisfy(isASCIIDigit),
      integerPart == "0" || integerPart.first != "0"
    else {
      throw SetRefValidationError.invalidWeight(value)
    }

    let fractionalPart = parts.count == 2 ? parts[1] : Substring()
    guard fractionalPart.count <= fractionalPlaces,
      parts.count == 1 || !fractionalPart.isEmpty,
      fractionalPart.utf8.allSatisfy(isASCIIDigit)
    else {
      throw SetRefValidationError.invalidWeight(value)
    }

    guard let integer = Int(integerPart) else {
      throw SetRefValidationError.invalidWeight(value)
    }
    var minorUnits = integer
    for _ in 0..<fractionalPlaces {
      minorUnits *= 10
    }

    if !fractionalPart.isEmpty {
      guard let fraction = Int(fractionalPart) else {
        throw SetRefValidationError.invalidWeight(value)
      }
      var paddedFraction = fraction
      for _ in fractionalPart.count..<fractionalPlaces {
        paddedFraction *= 10
      }
      minorUnits += paddedFraction
    }
    return minorUnits
  }

  private static func canonicalDecimal(minorUnits: Int, fractionalPlaces: Int) -> String {
    var scale = 1
    for _ in 0..<fractionalPlaces {
      scale *= 10
    }
    let integer = minorUnits / scale
    let fraction = minorUnits % scale
    guard fraction != 0 else {
      return String(integer)
    }

    var digits = String(fraction)
    while digits.count < fractionalPlaces {
      digits.insert("0", at: digits.startIndex)
    }
    while digits.last == "0" {
      digits.removeLast()
    }
    return "\(integer).\(digits)"
  }

  private static func isASCIIDigit(_ value: UInt8) -> Bool {
    (48...57).contains(value)
  }
}

private struct SetRefAnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}
