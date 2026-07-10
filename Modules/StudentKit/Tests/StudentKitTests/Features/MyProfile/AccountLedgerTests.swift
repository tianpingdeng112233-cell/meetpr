import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func deleteAccountRequiresExactConfirmationWord() async throws {
  let repository = InMemoryAccountRepository()
  var loggedOut = false
  let viewModel = DeleteAccountViewModel(account: repository) { loggedOut = true }

  viewModel.confirmationText = "注 销"
  #expect(!viewModel.canSubmit)
  await viewModel.submit()
  #expect(await repository.deleted == false)

  viewModel.confirmationText = "注销"
  #expect(viewModel.canSubmit)
  await viewModel.submit()
  #expect(await repository.deleted)
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
  #expect(viewModel.canSubmit)
  guard case .failed = viewModel.state else {
    Issue.record("Expected failed state, got \(viewModel.state)")
    return
  }
}

@MainActor
@Test func changePasswordValidatesLocallyAndMapsMismatch() async throws {
  let repository = InMemoryAccountRepository(password: "right-pass-1")
  let viewModel = ChangePasswordViewModel(account: repository)

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
  await viewModel.submit()
  #expect(viewModel.state == .failed("旧密码不正确"))

  viewModel.oldPassword = "right-pass-1"
  await viewModel.submit()
  #expect(viewModel.state == .saved)
  #expect(await repository.currentPassword() == "new-pass-123")
}

@Test func backendAccountRepositoryMapsPasswordMismatchEnvelope() async throws {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(#"{"error":"PASSWORD_MISMATCH"}"#.utf8), statusCode: 403)
  }
  let repository = BackendAccountRepository(api: api, session: AccountSessionReader())

  await #expect(throws: AccountRepositoryError.passwordMismatch) {
    try await repository.changePassword(old: "wrong-pass", new: "new-pass-123")
  }
}

@Test func csvExporterEscapesNamesAndFallsBackToPlanExerciseID() throws {
  let namedID = UUID()
  let orphanID = try #require(UUID(uuidString: "AAAAAAAA-0000-4000-8000-0000000000AA"))
  let studentID = UUID()
  let names: [UUID: (name: String, nameEn: String?)] = [
    namedID: (name: "深蹲,低杠 \"竞技\"", nameEn: "Low-Bar Squat")
  ]
  let logs = [
    makeLog(studentID: studentID, planExerciseID: namedID, setIndex: 1, seconds: 0),
    makeLog(studentID: studentID, planExerciseID: orphanID, setIndex: 2, seconds: 3_600),
  ]

  let csv = TrainingLogCSVExporter.csv(logs: logs, names: names, calendar: utcCalendar())
  let lines = csv.split(separator: "\n")

  #expect(lines.count == 3)
  #expect(lines[0] == Substring(TrainingLogCSVExporter.header))
  #expect(lines[1].contains("\"深蹲,低杠 \"\"竞技\"\"\""))
  #expect(lines[1].contains("142.5,5,8.5,true,false,false"))
  #expect(lines[2].contains(orphanID.uuidString))
}

@Test func csvExporterEmptyDataStillProducesHeader() {
  let csv = TrainingLogCSVExporter.csv(logs: [], names: [:])
  #expect(csv == TrainingLogCSVExporter.header)
}

@Test func csvExporterPreservesOneHundredRows() {
  let studentID = UUID()
  let planExerciseID = UUID()
  let logs = (0..<100).map { index in
    makeLog(
      studentID: studentID,
      planExerciseID: planExerciseID,
      setIndex: index + 1,
      seconds: TimeInterval(index)
    )
  }

  let csv = TrainingLogCSVExporter.csv(logs: logs, names: [:], calendar: utcCalendar())
  #expect(csv.split(separator: "\n").count == 101)
}

private struct FailingAccountRepository: AccountRepository {
  func deleteAccount() async throws {
    throw URLError(.notConnectedToInternet)
  }

  func changePassword(old: String, new: String) async throws {
    throw URLError(.notConnectedToInternet)
  }
}

private struct AccountSessionReader: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private func makeLog(
  studentID: UUID,
  planExerciseID: UUID,
  setIndex: Int,
  seconds: TimeInterval
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: planExerciseID,
    setIndex: setIndex,
    loggedAt: Date(timeIntervalSince1970: 1_783_296_000 + seconds),
    weightKg: 142.5,
    reps: 5,
    rpe: 8.5,
    completed: true
  )
}

private func utcCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
  return calendar
}
