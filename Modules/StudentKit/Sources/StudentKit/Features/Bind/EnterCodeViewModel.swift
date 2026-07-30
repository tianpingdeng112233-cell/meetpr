import Analytics
import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class EnterCodeViewModel {
  public enum SubmitOutcome: Equatable, Sendable {
    /// POSTed directly (onboarding already complete, spec 031 D1 exception).
    case requestSent(BindRequest)
    /// Stashed; BindGate routes into the 032 wizard.
    case stashedForOnboarding(PendingBindCode)
    /// already-pending / already-bound — server state advanced elsewhere.
    case needsReload
  }

  public enum FieldError: Equatable, Sendable {
    case invalidCode

    public var message: String {
      switch self {
      case .invalidCode:
        "这个码不存在或已过期。让教练在「我的」→「我的邀请码」里重新生成一个。"
      }
    }
  }

  public var codeInput: String = ""
  public var displayName: String = ""
  public private(set) var fieldError: FieldError?
  public private(set) var showsNetworkBanner = false
  public private(set) var isSubmitting = false

  private let bind: any BindRepository
  private let stash: any PendingBindCodeStoring
  private let isOnboardingComplete: @Sendable () async -> Bool
  private let studentId: UUID
  private let now: @Sendable () -> Date

  public init(
    studentId: UUID,
    bind: any BindRepository,
    stash: any PendingBindCodeStoring,
    isOnboardingComplete: @escaping @Sendable () async -> Bool,
    prefillDisplayName: String? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentId = studentId
    self.bind = bind
    self.stash = stash
    self.isOnboardingComplete = isOnboardingComplete
    self.displayName = prefillDisplayName ?? ""
    self.now = now
  }

  /// Uppercased, separator-stripped working copy of the code field.
  public var normalizedCode: String {
    InviteCodeFormat.normalize(codeInput)
  }

  /// Grouped echo under the input ("XK7M PQ2 RVT") once 10 chars are in.
  public var groupedCodePreview: String? {
    InviteCodeFormat.isValid(normalizedCode) ? InviteCodeFormat.grouped(normalizedCode) : nil
  }

  public var trimmedDisplayName: String {
    displayName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Hard format gate (spec 031 D3): exactly 10 chars of the locked alphabet
  /// + 1-100 char name. The only pre-validation before the code reaches the
  /// backend — possibly after the whole 7-step wizard.
  public var isSubmittable: Bool {
    InviteCodeFormat.isValid(normalizedCode)
      && !trimmedDisplayName.isEmpty
      && trimmedDisplayName.count <= 100
      && !isSubmitting
  }

  public var codeFormatHint: String? {
    let code = normalizedCode
    guard !code.isEmpty, !InviteCodeFormat.isValid(code) else { return nil }
    return "邀请码为 10 位字母数字(不含 I/O/0/1)"
  }

  /// nil = stay on the page (field error / network banner shown).
  public func submit() async -> SubmitOutcome? {
    guard isSubmittable else { return nil }
    fieldError = nil
    showsNetworkBanner = false

    let pending = PendingBindCode(
      code: normalizedCode, displayName: trimmedDisplayName, stashedAt: now())

    guard await isOnboardingComplete() else {
      stash.stash(pending, studentId: studentId)
      Analytics.shared.bindCoachAction(.submitted)
      return .stashedForOnboarding(pending)
    }

    isSubmitting = true
    defer { isSubmitting = false }
    do {
      let request = try await bind.submitBindRequest(
        code: pending.code, displayName: pending.displayName)
      Analytics.shared.bindCoachAction(.submitted)
      return .requestSent(request)
    } catch BindRequestError.invalidCode {
      fieldError = .invalidCode
      Analytics.shared.validationError(flow: .bind, field: .inviteCode)
      return nil
    } catch BindRequestError.alreadyPending, BindRequestError.alreadyBound {
      return .needsReload
    } catch {
      showsNetworkBanner = true
      return nil
    }
  }
}
