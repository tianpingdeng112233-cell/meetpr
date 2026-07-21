import Observation
import RepositoryContracts

@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
final class CoachChangePasswordViewModel {
  enum State: Equatable {
    case idle
    case submitting
    case saved
    case failed(String)
  }

  var oldPassword = ""
  var newPassword = ""
  var confirmPassword = ""
  private(set) var state: State = .idle

  private let account: any AccountRepository

  init(account: any AccountRepository) {
    self.account = account
  }

  var localValidationMessage: String? {
    if !newPassword.isEmpty, newPassword.count < 8 {
      return "新密码至少 8 位"
    }
    if !confirmPassword.isEmpty, newPassword != confirmPassword {
      return "两次输入的新密码不一致"
    }
    return nil
  }

  var canSubmit: Bool {
    !oldPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
      && state != .submitting
  }

  func submit() async {
    guard canSubmit else { return }
    state = .submitting
    do {
      try await account.changePassword(old: oldPassword, new: newPassword)
      state = .saved
    } catch AccountRepositoryError.passwordMismatch {
      state = .failed("旧密码不正确")
    } catch {
      state = .failed("修改失败,请检查网络后重试")
    }
  }
}
