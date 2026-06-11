import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// MARK: - Cancel outcomes (spec 031 §7 / risk 4)

@MainActor
@Test func cancelSuccessReportsCancelled() async {
  let repo = ScriptedBindRepository(cancel: [nil])
  let viewModel = PendingBindViewModel(bind: repo)
  let requestId = BindFixtures.request(status: .pending).id

  let outcome = await viewModel.cancel(requestId: requestId)

  #expect(outcome == .cancelled)
  #expect(repo.cancelledIds == [requestId])
  #expect(viewModel.cancelError == nil)
}

@MainActor
@Test func cancelRacingAcceptanceConvergesSilently() async {
  // Coach accepted while the student tapped cancel: 409 NOT_PENDING must not
  // surface as an error — the gate reloads and lands on .bound.
  let repo = ScriptedBindRepository(cancel: [BindRequestError.notPending])
  let viewModel = PendingBindViewModel(bind: repo)

  let outcome = await viewModel.cancel(requestId: UUID())

  #expect(outcome == .alreadyResponded)
  #expect(viewModel.cancelError == nil)
}

@MainActor
@Test func cancelTransportFailureShowsInlineError() async {
  let repo = ScriptedBindRepository(cancel: [TransportFailure()])
  let viewModel = PendingBindViewModel(bind: repo)

  let outcome = await viewModel.cancel(requestId: UUID())

  #expect(outcome == nil)
  #expect(viewModel.cancelError != nil)
}

// MARK: - Waiting duration formatting

@Test func waitingDescriptionFormatsMinutesHoursDays() {
  let start = BindFixtures.referenceDate

  #expect(
    PendingBindViewModel.waitingDescription(
      since: start, now: start.addingTimeInterval(40)) == "0 分钟")
  #expect(
    PendingBindViewModel.waitingDescription(
      since: start, now: start.addingTimeInterval(14 * 60)) == "14 分钟")
  #expect(
    PendingBindViewModel.waitingDescription(
      since: start, now: start.addingTimeInterval(2 * 3600 + 14 * 60)) == "2 小时 14 分")
  #expect(
    PendingBindViewModel.waitingDescription(
      since: start, now: start.addingTimeInterval(3 * 86_400 + 5 * 3600)) == "3 天 5 小时")
}

@Test func waitingDescriptionClampsClockSkewToZero() {
  let start = BindFixtures.referenceDate
  #expect(
    PendingBindViewModel.waitingDescription(
      since: start, now: start.addingTimeInterval(-300)) == "0 分钟")
}
