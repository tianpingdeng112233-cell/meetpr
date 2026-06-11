import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview bind store (spec 031 §9). Mirrors the backend semantics the
/// UI depends on — typed errors, single live request, status flips — but not
/// the lazy-expiry clock (expiry timing is covered by Backend repo tests
/// with a mock transport, spec 031 risk 6).
public actor InMemoryBindRepository: BindRepository {
  /// code → coach identity for submit simulation.
  public struct CoachSeed: Sendable {
    public let coachId: UUID
    public let coachDisplayName: String?

    public init(coachId: UUID, coachDisplayName: String?) {
      self.coachId = coachId
      self.coachDisplayName = coachDisplayName
    }
  }

  private let studentId: UUID
  private var validCodes: [String: CoachSeed]
  private var latest: BindRequest?
  private let now: @Sendable () -> Date

  public init(
    studentId: UUID,
    validCodes: [String: CoachSeed] = [:],
    seed: BindRequest? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentId = studentId
    self.validCodes = validCodes
    self.latest = seed
    self.now = now
  }

  public func submitBindRequest(code: String, displayName: String) async throws -> BindRequest {
    if latest?.status == .pending {
      throw BindRequestError.alreadyPending
    }
    guard let coach = validCodes[code] else {
      throw BindRequestError.invalidCode
    }
    if let latest, latest.status == .accepted, latest.coachId == coach.coachId {
      throw BindRequestError.alreadyBound
    }

    let submittedAt = now()
    let request = BindRequest(
      id: UUID(),
      studentId: studentId,
      coachId: coach.coachId,
      coachDisplayName: coach.coachDisplayName,
      inviteCodeId: UUID(),
      status: .pending,
      submittedAt: submittedAt,
      expiredAt: submittedAt.addingTimeInterval(7 * 86_400)
    )
    latest = request
    return request
  }

  public func myBindRequest() async throws -> BindRequest? {
    latest
  }

  public func cancelBindRequest(id: UUID) async throws {
    guard let current = latest, current.id == id else {
      throw BindRequestError.notFound
    }
    guard current.status == .pending else {
      throw BindRequestError.notPending
    }
    latest = BindRequest(
      id: current.id,
      studentId: current.studentId,
      coachId: current.coachId,
      coachDisplayName: current.coachDisplayName,
      inviteCodeId: current.inviteCodeId,
      status: .cancelled,
      submittedAt: current.submittedAt,
      respondedAt: nil,
      expiredAt: current.expiredAt,
      skipEvaluation: current.skipEvaluation,
      skipReason: current.skipReason
    )
  }

  // MARK: - Test/demo helpers

  /// Simulates the coach responding (accept/reject) out of band.
  public func setLatest(_ request: BindRequest?) {
    latest = request
  }
}
