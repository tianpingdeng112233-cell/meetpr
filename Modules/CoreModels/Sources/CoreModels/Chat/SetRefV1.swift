import Foundation

// The strict wire shape, canonical formatter, and digit-by-digit decimal validator
// intentionally stay together so both logged and planned snapshots share one contract.
// swiftlint:disable file_length

public enum SetRefValidationError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case invalidExerciseName
  case invalidSetNumber(Int)
  case invalidSetTotal(Int)
  case setNumberExceedsSetTotal(setNumber: Int, setTotal: Int)
  case invalidWeight(String)
  case invalidReps(Int)
  case invalidRepsMaximum(reps: Int?, repsMax: Int)
  case invalidRPE(String)
  case invalidDayDate(String)
  case invalidSourceIdentifiers(
    source: SetRefSource,
    setLogId: UUID?,
    planSetId: UUID?
  )
  case missingField(String)
  case unknownFields([String])
}

public enum SetRefSource: String, Codable, Hashable, Sendable {
  case logged
  case planned
}

public struct SetRefSourceSnapshot: Sendable {
  public let source: SetRefSource
  public let exerciseName: String
  public let setNumber: Int
  public let setTotal: Int?
  public let weightKg: String?
  public let reps: Int?
  public let repsMax: Int?
  public let rpe: String?
  public let dayDate: String
  public let setLogId: UUID?
  public let planSetId: UUID?

  public init(
    source: SetRefSource,
    exerciseName: String,
    setNumber: Int,
    setTotal: Int?,
    weightKg: String?,
    reps: Int?,
    repsMax: Int?,
    rpe: String?,
    dayDate: String,
    setLogId: UUID?,
    planSetId: UUID?
  ) {
    self.source = source
    self.exerciseName = exerciseName
    self.setNumber = setNumber
    self.setTotal = setTotal
    self.weightKg = weightKg
    self.reps = reps
    self.repsMax = repsMax
    self.rpe = rpe
    self.dayDate = dayDate
    self.setLogId = setLogId
    self.planSetId = planSetId
  }
}

/// Frozen, canonical snapshot of one logged or planned training set shared through chat.
///
/// Decimal values stay as strings at the wire boundary. Construction from source
/// wire values parses them into integer minor units before producing the canonical
/// strings held by this value.
public struct SetRefV1: Codable, Hashable, Sendable {
  public let version: Int
  public let source: SetRefSource
  public let exerciseName: String
  public let setNumber: Int
  public let setTotal: Int?
  public let weightKg: String?
  public let reps: Int?
  public let repsMax: Int?
  public let rpe: String?
  public let dayDate: String
  public let setLogId: UUID?
  public let planSetId: UUID?

  public init(
    version: Int = 1,
    source: SetRefSource,
    exerciseName: String,
    setNumber: Int,
    setTotal: Int?,
    weightKg: String?,
    reps: Int?,
    repsMax: Int?,
    rpe: String?,
    dayDate: String,
    setLogId: UUID?,
    planSetId: UUID?
  ) throws {
    try Self.validateVersion(version)
    try Self.validateExerciseName(exerciseName)
    try Self.validateSetNumber(setNumber)
    try weightKg.map(Self.validateCanonicalWeight)
    try reps.map(Self.validateReps)
    try rpe.map(Self.validateCanonicalRPE)
    try Self.validateDayDate(dayDate)
    try Self.validateSourceIdentifiers(
      source: source,
      setLogId: setLogId,
      planSetId: planSetId
    )
    try setTotal.map(Self.validateSetTotal)
    try Self.validateSetNumber(setNumber, within: setTotal)
    try Self.validateRepsMaximum(repsMax, lowerBound: reps)

    self.version = version
    self.source = source
    self.exerciseName = exerciseName
    self.setNumber = setNumber
    self.setTotal = setTotal
    self.weightKg = weightKg
    self.reps = reps
    self.repsMax = repsMax
    self.rpe = rpe
    self.dayDate = dayDate
    self.setLogId = setLogId
    self.planSetId = planSetId
  }

  /// Builds a canonical snapshot from fixed-precision source wire strings.
  ///
  /// Examples: `"100.00"` becomes `"100"` and `"8.0"` becomes `"8"`.
  /// Parsing is digit-by-digit; no binary floating-point value is created.
  public static func normalizingSource(_ source: SetRefSourceSnapshot) throws -> SetRefV1 {
    let normalizedWeight = try source.weightKg.map(normalizeWeight)
    let normalizedRPE = try source.rpe.map(normalizeRPE)
    return try SetRefV1(
      source: source.source,
      exerciseName: source.exerciseName,
      setNumber: source.setNumber,
      setTotal: source.setTotal,
      weightKg: normalizedWeight,
      reps: source.reps,
      repsMax: source.repsMax,
      rpe: normalizedRPE,
      dayDate: source.dayDate,
      setLogId: source.setLogId,
      planSetId: source.planSetId
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
      source: container.decode(SetRefSource.self, forKey: .source),
      exerciseName: container.decode(String.self, forKey: .exerciseName),
      setNumber: container.decode(Int.self, forKey: .setNumber),
      setTotal: container.decodeIfPresent(Int.self, forKey: .setTotal),
      weightKg: container.decodeIfPresent(String.self, forKey: .weightKg),
      reps: container.decodeIfPresent(Int.self, forKey: .reps),
      repsMax: container.decodeIfPresent(Int.self, forKey: .repsMax),
      rpe: container.decodeIfPresent(String.self, forKey: .rpe),
      dayDate: container.decode(String.self, forKey: .dayDate),
      setLogId: container.decodeIfPresent(UUID.self, forKey: .setLogId),
      planSetId: container.decodeIfPresent(UUID.self, forKey: .planSetId)
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(source, forKey: .source)
    try container.encode(exerciseName, forKey: .exerciseName)
    try container.encode(setNumber, forKey: .setNumber)
    try container.encode(setTotal, forKey: .setTotal)
    try container.encode(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encode(repsMax, forKey: .repsMax)
    try container.encode(rpe, forKey: .rpe)
    try container.encode(dayDate, forKey: .dayDate)
    try container.encode(setLogId, forKey: .setLogId)
    try container.encode(planSetId, forKey: .planSetId)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case version = "v"
    case source
    case exerciseName
    case setNumber
    case setTotal
    case weightKg
    case reps
    case repsMax
    case rpe
    case dayDate
    case setLogId
    case planSetId
  }
}

public enum SetRefCanonicalFormatter {
  public static func firstLine(for setRef: SetRefV1) -> String {
    let prefix = setRef.source == .logged ? "[训练分享]" : "[训练计划]"
    let setTotal = setRef.setTotal.map { "/\($0)" } ?? ""
    let plannedMarker = setRef.source == .planned ? " 计划" : ""
    let weight = setRef.weightKg.map { "\($0)kg" } ?? "-kg"
    let reps: String
    if let lowerBound = setRef.reps, let upperBound = setRef.repsMax {
      reps = "\(lowerBound)-\(upperBound)"
    } else {
      reps = setRef.reps.map(String.init) ?? "-"
    }
    let rpe = setRef.rpe.map { " @RPE\($0)" } ?? ""
    return
      "\(prefix) \(setRef.exerciseName) 第\(setRef.setNumber)组\(setTotal)\(plannedMarker) "
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

  private static func validateSetTotal(_ value: Int) throws {
    guard (1...999).contains(value) else {
      throw SetRefValidationError.invalidSetTotal(value)
    }
  }

  private static func validateSetNumber(_ setNumber: Int, within setTotal: Int?) throws {
    guard let setTotal else { return }
    guard setNumber <= setTotal else {
      throw SetRefValidationError.setNumberExceedsSetTotal(
        setNumber: setNumber,
        setTotal: setTotal
      )
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

  private static func validateRepsMaximum(_ repsMax: Int?, lowerBound reps: Int?) throws {
    guard let repsMax else { return }
    guard let reps, reps < repsMax, repsMax <= 99 else {
      throw SetRefValidationError.invalidRepsMaximum(reps: reps, repsMax: repsMax)
    }
  }

  private static func validateCanonicalRPE(_ value: String) throws {
    guard try normalizeRPE(value) == value else {
      throw SetRefValidationError.invalidRPE(value)
    }
  }

  private static func validateSourceIdentifiers(
    source: SetRefSource,
    setLogId: UUID?,
    planSetId: UUID?
  ) throws {
    let isValid =
      switch source {
      case .logged:
        setLogId != nil && planSetId == nil
      case .planned:
        planSetId != nil && setLogId == nil
      }
    guard isValid else {
      throw SetRefValidationError.invalidSourceIdentifiers(
        source: source,
        setLogId: setLogId,
        planSetId: planSetId
      )
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

// swiftlint:enable file_length
