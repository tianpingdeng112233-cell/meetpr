import CoreModels
import Foundation
import Networking

public struct CoachExerciseStatsSnapshot: Equatable, Sendable {
  public struct E1RMValue: Equatable, Sendable {
    public let valueKg: Decimal

    public init(valueKg: Decimal) {
      self.valueKg = valueKg
    }
  }

  public struct Point: Equatable, Sendable {
    public let date: Date
    public let valueKg: Decimal

    public init(date: Date, valueKg: Decimal) {
      self.date = date
      self.valueKg = valueKg
    }
  }

  public struct FamilySeries: Equatable, Sendable {
    public let points: [Point]
    public let trend: Trend

    public init(points: [Point], trend: Trend) {
      self.points = points
      self.trend = trend
    }
  }

  public enum Trend: Equatable, Sendable {
    case upward
    case steady
    case downward
    case new
    case unknown(String)
  }

  public let e1RMByFamily: [LiftFamily: E1RMValue]
  public let seriesByFamily: [LiftFamily: FamilySeries]
  public let oneRMByFamily: [LiftFamily: Decimal]

  public init(
    e1RMByFamily: [LiftFamily: E1RMValue] = [:],
    seriesByFamily: [LiftFamily: FamilySeries] = [:],
    oneRMByFamily: [LiftFamily: Decimal] = [:]
  ) {
    self.e1RMByFamily = e1RMByFamily
    self.seriesByFamily = seriesByFamily
    self.oneRMByFamily = oneRMByFamily
  }
}

public protocol CoachExerciseStatsProviding: Sendable {
  func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot
}

public enum CoachExerciseStatsRepositoryError: Error, Equatable, Sendable {
  case invalidDecimal(String)
  case invalidDate(String)
}

public actor BackendCoachExerciseStatsRepository: CoachExerciseStatsProviding {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot {
    let token = try await session.accessToken()
    let response = try await api.coachStudentExerciseStats(
      studentID: studentID,
      accessToken: token
    )
    return try Self.snapshot(from: response)
  }

  static func snapshot(
    from response: CoachExerciseStatsResponseDTO
  ) throws -> CoachExerciseStatsSnapshot {
    var e1RMByFamily: [LiftFamily: CoachExerciseStatsSnapshot.E1RMValue] = [:]
    if let values = response.e1RM {
      for (family, value) in Self.familyValues(values) {
        guard let decimal = Self.decimal(value.value) else {
          throw CoachExerciseStatsRepositoryError.invalidDecimal(value.value)
        }
        e1RMByFamily[family] = .init(valueKg: decimal)
      }
    }

    var seriesByFamily: [LiftFamily: CoachExerciseStatsSnapshot.FamilySeries] = [:]
    if let series = response.e1RMSeries {
      for (family, familySeries) in Self.familySeries(series) {
        let points = try familySeries.points.map { point in
          guard let date = Self.date(point.date) else {
            throw CoachExerciseStatsRepositoryError.invalidDate(point.date)
          }
          guard let value = Self.decimal(point.value) else {
            throw CoachExerciseStatsRepositoryError.invalidDecimal(point.value)
          }
          return CoachExerciseStatsSnapshot.Point(date: date, valueKg: value)
        }
        seriesByFamily[family] = .init(
          points: points,
          trend: Self.trend(familySeries.trend)
        )
      }
    }

    var oneRMByFamily: [LiftFamily: Decimal] = [:]
    for (family, rawValue) in Self.oneRMValues(response.oneRM) {
      guard let decimal = Self.decimal(rawValue) else {
        throw CoachExerciseStatsRepositoryError.invalidDecimal(rawValue)
      }
      oneRMByFamily[family] = decimal
    }

    return CoachExerciseStatsSnapshot(
      e1RMByFamily: e1RMByFamily,
      seriesByFamily: seriesByFamily,
      oneRMByFamily: oneRMByFamily
    )
  }

  private static func familyValues(
    _ values: ExerciseStatsE1RMDTO
  ) -> [(LiftFamily, ExerciseStatsE1RMValueDTO)] {
    [
      values.squat.map { (.squat, $0) },
      values.bench.map { (.bench, $0) },
      values.deadlift.map { (.deadlift, $0) },
    ].compactMap { $0 }
  }

  private static func familySeries(
    _ series: ExerciseStatsE1RMSeriesDTO
  ) -> [(LiftFamily, ExerciseStatsE1RMFamilySeriesDTO)] {
    [
      (.squat, series.squat),
      (.bench, series.bench),
      (.deadlift, series.deadlift),
    ]
  }

  private static func oneRMValues(
    _ values: ExerciseStatsOneRMDTO
  ) -> [(LiftFamily, String)] {
    [
      values.squat.map { (.squat, $0) },
      values.bench.map { (.bench, $0) },
      values.deadlift.map { (.deadlift, $0) },
    ].compactMap { $0 }
  }

  private static func decimal(_ rawValue: String) -> Decimal? {
    Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX"))
  }

  private static func date(_ rawValue: String) -> Date? {
    let components = rawValue.split(separator: "-", omittingEmptySubsequences: false)
    guard components.count == 3,
      let year = Int(components[0]),
      let month = Int(components[1]),
      let day = Int(components[2]),
      let timeZone = TimeZone(secondsFromGMT: 0)
    else { return nil }

    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = timeZone
    guard
      let date = calendar.date(
        from: DateComponents(
          calendar: calendar,
          timeZone: timeZone,
          year: year,
          month: month,
          day: day
        )
      )
    else { return nil }

    let resolved = calendar.dateComponents([.year, .month, .day], from: date)
    guard resolved.year == year, resolved.month == month, resolved.day == day else {
      return nil
    }
    return date
  }

  private static func trend(
    _ trend: ExerciseStatsE1RMTrendDTO
  ) -> CoachExerciseStatsSnapshot.Trend {
    switch trend {
    case .upward: .upward
    case .steady: .steady
    case .downward: .downward
    case .new: .new
    case .unknown(let rawValue): .unknown(rawValue)
    }
  }
}

public actor InMemoryCoachExerciseStatsRepository: CoachExerciseStatsProviding {
  private let snapshots: [UUID: CoachExerciseStatsSnapshot]

  public init(snapshots: [UUID: CoachExerciseStatsSnapshot] = [:]) {
    self.snapshots = snapshots
  }

  public func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot {
    snapshots[studentID] ?? CoachExerciseStatsSnapshot()
  }
}
