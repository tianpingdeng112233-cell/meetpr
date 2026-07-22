import CoreModels
import Foundation
import RepositoryContracts

@testable import StudentKit

// MARK: - Fixtures

enum BindFixtures {
  static let studentId = UUID(uuidString: "0a000000-0000-0000-0000-000000000001")!
  static let coachId = UUID(uuidString: "0a000000-0000-0000-0000-000000000002")!
  static let referenceDate = Date(timeIntervalSince1970: 1_780_000_000)

  static func request(
    status: BindRequestStatus,
    submittedAt: Date = referenceDate,
    coachId: UUID = BindFixtures.coachId,
    coachDisplayName: String? = "David",
    skipEvaluation: Bool = false
  ) -> BindRequest {
    BindRequest(
      id: UUID(uuidString: "0a000000-0000-0000-0000-00000000000f")!,
      studentId: studentId,
      coachId: coachId,
      coachDisplayName: coachDisplayName,
      inviteCodeId: UUID(),
      status: status,
      submittedAt: submittedAt,
      respondedAt: nil,
      expiredAt: submittedAt.addingTimeInterval(7 * 86_400),
      skipEvaluation: skipEvaluation
    )
  }

  static func pendingCode(
    code: String = "XK7MPQ2RVT",
    displayName: String = "张三"
  ) -> PendingBindCode {
    PendingBindCode(code: code, displayName: displayName, stashedAt: referenceDate)
  }
}

// MARK: - Scripted bind repository

/// Scriptable BindRepository: each call pops a scripted result so tests can
/// model sequences (e.g. submit conflict → re-read converges).
final class ScriptedBindRepository: BindRepository, @unchecked Sendable {
  enum SubmitResult {
    case success(BindRequest)
    case failure(any Error)
  }

  enum MineResult {
    case success(BindRequest?)
    case failure(any Error)
  }

  private let lock = NSLock()
  private var mineResults: [MineResult]
  private var submitResults: [SubmitResult]
  private var cancelErrors: [(any Error)?]
  private(set) var submitCalls: [(code: String, displayName: String)] = []
  private(set) var mineCallCount = 0
  private(set) var cancelledIds: [UUID] = []

  init(
    mine: [MineResult] = [],
    submit: [SubmitResult] = [],
    cancel: [(any Error)?] = []
  ) {
    self.mineResults = mine
    self.submitResults = submit
    self.cancelErrors = cancel
  }

  /// Append a scripted submit result after construction.
  func scriptSubmit(_ result: SubmitResult) {
    lock.lock()
    defer { lock.unlock() }
    submitResults.append(result)
  }

  func submitBindRequest(code: String, displayName: String) async throws -> BindRequest {
    lock.lock()
    submitCalls.append((code, displayName))
    let result = submitResults.isEmpty ? nil : submitResults.removeFirst()
    lock.unlock()
    switch result {
    case .success(let request): return request
    case .failure(let error): throw error
    case nil: throw BindRequestError.invalidCode
    }
  }

  func myBindRequest() async throws -> BindRequest? {
    lock.lock()
    mineCallCount += 1
    let result = mineResults.isEmpty ? nil : mineResults.removeFirst()
    lock.unlock()
    switch result {
    case .success(let request): return request
    case .failure(let error): throw error
    case nil: return nil
    }
  }

  func cancelBindRequest(id: UUID) async throws {
    lock.lock()
    cancelledIds.append(id)
    let error = cancelErrors.isEmpty ? nil : cancelErrors.removeFirst()
    lock.unlock()
    if let error { throw error }
  }
}

struct TransportFailure: Error {}

// MARK: - In-memory stash

final class StashSpy: PendingBindCodeStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [UUID: PendingBindCode] = [:]

  init(seed: [UUID: PendingBindCode] = [:]) {
    storage = seed
  }

  func stash(_ pending: PendingBindCode, studentId: UUID) {
    lock.lock()
    defer { lock.unlock() }
    storage[studentId] = pending
  }

  func peek(studentId: UUID) -> PendingBindCode? {
    lock.lock()
    defer { lock.unlock() }
    return storage[studentId]
  }

  func clear(studentId: UUID) {
    lock.lock()
    defer { lock.unlock() }
    storage[studentId] = nil
  }
}
