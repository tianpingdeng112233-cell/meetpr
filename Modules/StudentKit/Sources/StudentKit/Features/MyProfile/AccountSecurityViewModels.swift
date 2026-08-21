import Foundation
import Observation
import RepositoryContracts

@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class DeleteAccountViewModel {
  public enum State: Equatable {
    case idle
    case deleting
    case failed(String)
  }

  public static let requiredWord = StudentStrings.localized(.accountSecurityViewModels001)

  public var confirmationText = ""
  public private(set) var state: State = .idle

  private let account: any AccountRepository
  private let onDeleted: @MainActor () async -> Void

  public init(
    account: any AccountRepository,
    onDeleted: @escaping @MainActor () async -> Void
  ) {
    self.account = account
    self.onDeleted = onDeleted
  }

  public var canSubmit: Bool {
    confirmationText == Self.requiredWord && state != .deleting
  }

  public func submit() async {
    guard canSubmit else { return }
    state = .deleting
    do {
      try await account.deleteAccount()
      await onDeleted()
    } catch {
      state = .failed(StudentStrings.localized(.accountSecurityViewModels002))
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class ChangePasswordViewModel {
  public enum State: Equatable {
    case idle
    case submitting
    case saved
    case failed(String)
  }

  public var oldPassword = ""
  public var newPassword = ""
  public var confirmPassword = ""
  public private(set) var state: State = .idle

  private let account: any AccountRepository

  public init(account: any AccountRepository) {
    self.account = account
  }

  public var localValidationMessage: String? {
    if !newPassword.isEmpty, newPassword.count < 8 {
      return StudentStrings.localized(.accountSecurityViewModels003)
    }
    if !confirmPassword.isEmpty, newPassword != confirmPassword {
      return StudentStrings.localized(.accountSecurityViewModels004)
    }
    return nil
  }

  public var canSubmit: Bool {
    !oldPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
      && state != .submitting
  }

  public func submit() async {
    guard canSubmit else { return }
    state = .submitting
    do {
      try await account.changePassword(old: oldPassword, new: newPassword)
      state = .saved
    } catch AccountRepositoryError.passwordMismatch {
      state = .failed(StudentStrings.localized(.accountSecurityViewModels005))
    } catch {
      state = .failed(StudentStrings.localized(.accountSecurityViewModels006))
    }
  }
}
