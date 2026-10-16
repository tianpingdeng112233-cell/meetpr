import Foundation

/// Backend specs 018 §6 and 021 §1 coach discovery responses.
public struct CoachSignalsResponseDTO: Codable, Equatable, Sendable {
  public let signals: [CoachSignalDTO]

  public init(signals: [CoachSignalDTO]) {
    self.signals = signals
  }
}

public struct CoachSignalDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let studentName: String
  public let signalType: String
  public let severity: String
  public let status: String
  public let reason: String
  public let payload: CoachSignalPayloadDTO
  public let openedAt: Date
  public let expiresAt: Date?

  public init(
    id: UUID,
    studentId: UUID,
    studentName: String,
    signalType: String,
    severity: String,
    status: String,
    reason: String,
    payload: CoachSignalPayloadDTO,
    openedAt: Date,
    expiresAt: Date?
  ) {
    self.id = id
    self.studentId = studentId
    self.studentName = studentName
    self.signalType = signalType
    self.severity = severity
    self.status = status
    self.reason = reason
    self.payload = payload
    self.openedAt = openedAt
    self.expiresAt = expiresAt
  }
}

/// Additive union of the three signal payloads. Unknown backend keys remain
/// forward-compatible because Codable ignores keys this client does not use.
public struct CoachSignalPayloadDTO: Codable, Equatable, Sendable {
  public let missedDates: [String]?
  public let consecutiveCount: Int?
  public let planId: UUID?
  public let streakStartDate: String?
  public let absenceEpoch: String?
  public let gymDay: String?
  public let failedCount: Int?
  public let setLogId: UUID?
  public let exerciseId: UUID?
  public let family: String?
  public let e1rm: Double?
  public let previousBest: Double?
  public let loggedDate: String?

  public init(
    missedDates: [String]? = nil,
    consecutiveCount: Int? = nil,
    planId: UUID? = nil,
    streakStartDate: String? = nil,
    absenceEpoch: String? = nil,
    gymDay: String? = nil,
    failedCount: Int? = nil,
    setLogId: UUID? = nil,
    exerciseId: UUID? = nil,
    family: String? = nil,
    e1rm: Double? = nil,
    previousBest: Double? = nil,
    loggedDate: String? = nil
  ) {
    self.missedDates = missedDates
    self.consecutiveCount = consecutiveCount
    self.planId = planId
    self.streakStartDate = streakStartDate
    self.absenceEpoch = absenceEpoch
    self.gymDay = gymDay
    self.failedCount = failedCount
    self.setLogId = setLogId
    self.exerciseId = exerciseId
    self.family = family
    self.e1rm = e1rm
    self.previousBest = previousBest
    self.loggedDate = loggedDate
  }
}

public struct CoachDailyDigestResponseDTO: Codable, Equatable, Sendable {
  public let gymDay: String
  public let counts: CoachDailyDigestCountsDTO
  public let body: String?

  public init(gymDay: String, counts: CoachDailyDigestCountsDTO, body: String?) {
    self.gymDay = gymDay
    self.counts = counts
    self.body = body
  }
}

public struct CoachDailyDigestCountsDTO: Codable, Equatable, Sendable {
  public let sessionCompleted: Int
  public let sessionPartial: Int
  public let missedTraining: Int
  public let weightFailed: Int
  public let prE1Rm: Int

  public init(
    sessionCompleted: Int,
    sessionPartial: Int,
    missedTraining: Int,
    weightFailed: Int,
    prE1Rm: Int
  ) {
    self.sessionCompleted = sessionCompleted
    self.sessionPartial = sessionPartial
    self.missedTraining = missedTraining
    self.weightFailed = weightFailed
    self.prE1Rm = prE1Rm
  }
}

extension APIClient {
  public func coachSignals(
    status: String = "open",
    accessToken: String
  ) async throws -> CoachSignalsResponseDTO {
    try await get(
      path: "/coach/signals",
      queryItems: [URLQueryItem(name: "status", value: status)],
      accessToken: accessToken
    )
  }

  public func coachDailyDigest(
    accessToken: String
  ) async throws -> CoachDailyDigestResponseDTO {
    try await get(path: "/coach/daily-digest", accessToken: accessToken)
  }
}
