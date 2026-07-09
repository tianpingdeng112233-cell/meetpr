import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// MARK: - 注销 (spec 048 §2)

@MainActor
@Test func deleteAccountRequiresExactConfirmationWord() async throws {
  let repo = InMemoryAccountRepository()
  var loggedOut = false
  let viewModel = DeleteAccountViewModel(account: repo) { loggedOut = true }

  viewModel.confirmationText = "注 销"
  #expect(!viewModel.canSubmit)
  await viewModel.submit()
  #expect(await repo.deleted == false)

  viewModel.confirmationText = "注销"
  #expect(viewModel.canSubmit)
  await viewModel.submit()
  #expect(await repo.deleted)
  #expect(loggedOut)
}

@MainActor
@Test func deleteAccountFailureKeepsLocalStateAndAllowsRetry() async {
  var loggedOut = false
  let viewModel = DeleteAccountViewModel(account: FailingAccountRepository()) {
    loggedOut = true
  }

  viewModel.confirmationText = "注销"
  await viewModel.submit()

  #expect(!loggedOut)
  guard case .failed = viewModel.state else {
    Issue.record("Expected failed state, got \(viewModel.state)")
    return
  }
}

// MARK: - 改密 (spec 048 §3)

@MainActor
@Test func changePasswordValidatesLocallyAndMapsMismatch() async throws {
  let repo = InMemoryAccountRepository(password: "right-pass-1")
  let viewModel = ChangePasswordViewModel(account: repo)

  viewModel.oldPassword = "wrong-pass-1"
  viewModel.newPassword = "short"
  viewModel.confirmPassword = "short"
  #expect(!viewModel.canSubmit)
  #expect(viewModel.localValidationMessage == "新密码至少 8 位")

  viewModel.newPassword = "new-pass-123"
  viewModel.confirmPassword = "new-pass-124"
  #expect(!viewModel.canSubmit)
  #expect(viewModel.localValidationMessage == "两次输入的新密码不一致")

  viewModel.confirmPassword = "new-pass-123"
  #expect(viewModel.canSubmit)
  await viewModel.submit()
  #expect(viewModel.state == .failed("旧密码不正确"))

  viewModel.oldPassword = "right-pass-1"
  await viewModel.submit()
  #expect(viewModel.state == .saved)
  #expect(await repo.currentPassword() == "new-pass-123")
}

// MARK: - CSV (spec 048 §4)

@MainActor
@Test func csvExporterEscapesAndFallsBack() {
  let exerciseID = UUID()
  let names: [UUID: (name: String, nameEn: String?)] = [
    exerciseID: (name: "深蹲,低杠 \"竞技\"", nameEn: "Low-Bar Squat")
  ]
  let orphanID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-0000000000AA")!
  let logs = [
    StudentSetLog(
      id: UUID(), studentID: UUID(), planExerciseID: nil, exerciseID: exerciseID,
      loggedDate: "2026-07-04", adhoc: true, setIndex: 1,
      loggedAt: Date(timeIntervalSince1970: 1_780_560_000),
      weightKg: 142.5, reps: 5, rpe: 8.5, completed: true),
    StudentSetLog(
      id: UUID(), studentID: UUID(), planExerciseID: nil, exerciseID: orphanID,
      loggedDate: "2026-07-04", adhoc: true, setIndex: 2,
      loggedAt: Date(timeIntervalSince1970: 1_780_563_600),
      weightKg: 60, reps: 8, rpe: nil, completed: true),
  ]

  let csv = TrainingLogCSVExporter.csv(logs: logs, names: names)
  let lines = csv.split(separator: "\n")

  #expect(lines.count == 3)
  #expect(lines[0] == Substring(TrainingLogCSVExporter.header))
  // Comma + quotes force RFC 4180 quoting with doubled inner quotes.
  #expect(lines[1].contains("\"深蹲,低杠 \"\"竞技\"\"\""))
  #expect(lines[1].contains("142.5,5,8.5,true,false,true"))
  // Unresolvable exercise id falls back to the raw UUID, never drops a row.
  #expect(lines[2].contains(orphanID.uuidString))
}

@MainActor
@Test func csvExporterEmptyDataStillProducesHeader() {
  let csv = TrainingLogCSVExporter.csv(logs: [], names: [:])
  #expect(csv == TrainingLogCSVExporter.header)
}

// MARK: - Fixtures

private struct FailingAccountRepository: AccountRepository {
  func deleteAccount() async throws {
    throw URLError(.notConnectedToInternet)
  }

  func changePassword(old: String, new: String) async throws {
    throw URLError(.notConnectedToInternet)
  }
}
