import CoreModels
import Foundation

/// Typed mirror of the backend accept/reject machine codes (spec 033 §5).
/// Deliberately separate from the student-side `BindRequestError`: the coach
/// queue needs `BIND_REQUEST_EXPIRED` and maps every case onto the same
/// "refresh queue + banner" recovery (spec 033 D12).
public enum CoachBindQueueError: Error, Equatable, Sendable {
  /// 404 BIND_REQUEST_NOT_FOUND
  case notFound
  /// 409 BIND_REQUEST_EXPIRED — lazy expiry flipped it during this request.
  case expired
  /// 409 BIND_REQUEST_NOT_PENDING — already accepted / rejected / cancelled.
  case notPending
  /// 409 BIND_ALREADY_BOUND
  case alreadyBound
}

extension CoachBindQueueError {
  /// nil means "not a bind-queue code — rethrow the original error".
  public init?(machineCode: String?) {
    switch machineCode {
    case "BIND_REQUEST_NOT_FOUND": self = .notFound
    case "BIND_REQUEST_EXPIRED": self = .expired
    case "BIND_REQUEST_NOT_PENDING": self = .notPending
    case "BIND_ALREADY_BOUND": self = .alreadyBound
    default: return nil
    }
  }
}

/// One pending receive-queue row (spec 033 §3): bind request basics plus the
/// 9-item onboarding summary. Pure data crossing CoachKit ↔ Networking; the
/// spec-002 `BindRequest` entity is the student-side shape and is not reused
/// here (spec 033 §1).
public struct CoachBindRequestItem: Hashable, Identifiable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let displayName: String
  public let submittedAt: Date
  public let expiredAt: Date
  public let onboarding: CoachBindRequestOnboardingSummary

  public init(
    id: UUID,
    studentId: UUID,
    displayName: String,
    submittedAt: Date,
    expiredAt: Date,
    onboarding: CoachBindRequestOnboardingSummary
  ) {
    self.id = id
    self.studentId = studentId
    self.displayName = displayName
    self.submittedAt = submittedAt
    self.expiredAt = expiredAt
    self.onboarding = onboarding
  }
}

/// The queue card's onboarding summary. All fields null (and `completed`
/// false) when the student never finished onboarding — the card degrades
/// (spec 033 §3). Age and waiting time are client-derived from `birthDate` /
/// `submittedAt` (backend spec 005 D13).
public struct CoachBindRequestOnboardingSummary: Hashable, Sendable {
  public let completed: Bool
  public let gender: Gender?
  /// "yyyy-MM-dd" date-only string, same convention as OnboardingProfile.
  public let birthDate: String?
  public let weightKg: Decimal?
  public let trainingYears: Int?
  public let squat1RMKg: Decimal?
  public let bench1RMKg: Decimal?
  public let deadlift1RMKg: Decimal?
  public let muscleGroupsToStrengthen: [MuscleGroup]
  public let gymTier: GymTier?
  public let isCompeting: Bool?
  /// "yyyy-MM-dd" date-only string.
  public let competitionDate: String?
  public let noteToCoach: String?
  public let uploadCount: Int

  public init(
    completed: Bool,
    gender: Gender? = nil,
    birthDate: String? = nil,
    weightKg: Decimal? = nil,
    trainingYears: Int? = nil,
    squat1RMKg: Decimal? = nil,
    bench1RMKg: Decimal? = nil,
    deadlift1RMKg: Decimal? = nil,
    muscleGroupsToStrengthen: [MuscleGroup] = [],
    gymTier: GymTier? = nil,
    isCompeting: Bool? = nil,
    competitionDate: String? = nil,
    noteToCoach: String? = nil,
    uploadCount: Int = 0
  ) {
    self.completed = completed
    self.gender = gender
    self.birthDate = birthDate
    self.weightKg = weightKg
    self.trainingYears = trainingYears
    self.squat1RMKg = squat1RMKg
    self.bench1RMKg = bench1RMKg
    self.deadlift1RMKg = deadlift1RMKg
    self.muscleGroupsToStrengthen = muscleGroupsToStrengthen
    self.gymTier = gymTier
    self.isCompeting = isCompeting
    self.competitionDate = competitionDate
    self.noteToCoach = noteToCoach
    self.uploadCount = uploadCount
  }
}

/// Coach receive queue (spec 033 §2-§5). Maps 1:1 onto the backend
/// /coach/bind-requests endpoints. No cache by design: the queue is lazily
/// expired server-side and must be live.
public protocol CoachBindQueueRepository: Sendable {
  /// Pending requests, submitted_at ASC (server order preserved).
  func fetchQueue() async throws -> [CoachBindRequestItem]
  /// Accepts with the fixed compatibility body defined by Networking.
  /// Throws `CoachBindQueueError`.
  func accept(requestID: UUID) async throws
  /// Silent neutral rejection — strict empty body, no reason field
  /// (spec 033 D10). Throws `CoachBindQueueError`.
  func reject(requestID: UUID) async throws
}
