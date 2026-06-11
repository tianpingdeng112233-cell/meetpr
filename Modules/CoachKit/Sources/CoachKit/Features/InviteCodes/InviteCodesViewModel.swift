import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class InviteCodesViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded([InviteCode])
    case failed
  }

  public private(set) var state: State = .idle
  public private(set) var isMutating = false
  public private(set) var actionError: String?
  /// Transient "已复制" feedback target (code id).
  public private(set) var copiedCodeID: UUID?

  private let repository: any InviteCodeRepository
  private let now: @Sendable () -> Date

  public init(
    repository: any InviteCodeRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.repository = repository
    self.now = now
  }

  public func loadIfNeeded() async {
    guard state == .idle else { return }
    await reload()
  }

  public func reload() async {
    if case .loaded = state {} else { state = .loading }
    do {
      state = .loaded(try await repository.listCodes())
    } catch {
      if case .loaded = state { return }
      state = .failed
    }
  }

  /// The single live personal code (backend's partial unique index
  /// guarantees at most one). nil → the explicit-generate empty state
  /// (spec 031 D6: no auto-creation on load).
  public var activePersonalCode: InviteCode? {
    codes.first { $0.type == .personalPermanent && $0.revokedAt == nil }
  }

  /// Non-personal codes, created_at DESC (server order preserved), split
  /// into live / defunct sections.
  public var liveSecondaryCodes: [InviteCode] {
    secondaryCodes.filter { !status(of: $0).isDefunct }
  }

  public var defunctSecondaryCodes: [InviteCode] {
    secondaryCodes.filter { status(of: $0).isDefunct }
  }

  public func status(of code: InviteCode) -> InviteCodeStatus {
    InviteCodeStatus.status(of: code, now: now())
  }

  /// Personal generate + regenerate (the backend transaction auto-revokes
  /// the previous active personal code).
  public func generatePersonalCode() async {
    await mutate {
      _ = try await self.repository.createCode(
        type: .personalPermanent, label: nil, expiresInDays: nil)
    }
  }

  public func createSingleUseCode(label: String?) async {
    await mutate {
      _ = try await self.repository.createCode(
        type: .singleUse, label: Self.normalized(label), expiresInDays: nil)
    }
  }

  public func createTimeLimitedCode(label: String?, expiresInDays: Int) async {
    await mutate {
      _ = try await self.repository.createCode(
        type: .timeLimited, label: Self.normalized(label), expiresInDays: expiresInDays)
    }
  }

  public func revoke(id: UUID) async {
    await mutate {
      try await self.repository.revokeCode(id: id)
    }
  }

  public func markCopied(_ code: InviteCode) {
    copiedCodeID = code.id
  }

  public func clearCopied() {
    copiedCodeID = nil
  }

  // MARK: - Helpers

  private var codes: [InviteCode] {
    if case .loaded(let codes) = state { return codes }
    return []
  }

  private var secondaryCodes: [InviteCode] {
    codes.filter { $0.type != .personalPermanent }
  }

  /// Every mutation re-pulls the list — the backend is the source of truth,
  /// local state is never patched up (spec 031 §8).
  private func mutate(_ operation: () async throws -> Void) async {
    isMutating = true
    defer { isMutating = false }
    actionError = nil
    do {
      try await operation()
      await reload()
    } catch {
      actionError = "操作失败,请重试"
    }
  }

  private static func normalized(_ label: String?) -> String? {
    let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : String(trimmed.prefix(100))
  }
}
