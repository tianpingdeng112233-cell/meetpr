import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

// MARK: - Queue loading

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func queueLoadsPendingItemsAndExposesCount() async {
  let viewModel = BindQueueViewModel(
    repository: StubBindQueueRepository(),
    now: { BindQueueFixtures.now }
  )

  await viewModel.loadIfNeeded()

  #expect(viewModel.state == .loaded)
  #expect(viewModel.pendingCount == 1)
  #expect(viewModel.items.first?.displayName == "张三")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptIntoEvaluationRemovesItemAndReportsEvaluationToast() async {
  let repository = StubBindQueueRepository(
    evaluationOnAccept: BindQueueFixtures.evaluation())
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()
  let item = viewModel.items[0]

  let accepted = await viewModel.accept(item, skipEvaluation: false, skipReason: nil)

  #expect(accepted)
  #expect(viewModel.items.isEmpty)
  #expect(viewModel.toastMessage == CoachBindStrings.text("coach.bind.acceptedEvaluation"))
  let recorded = await repository.acceptedRequests
  #expect(recorded.count == 1)
  #expect(recorded[0].skip == false)
  #expect(recorded[0].reason == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSkippingEvaluationCarriesTrimmedReasonOnlyOnSkipBranch() async {
  let repository = StubBindQueueRepository()
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()
  let item = viewModel.items[0]

  let accepted = await viewModel.accept(item, skipEvaluation: true, skipReason: "  老学员  ")

  #expect(accepted)
  #expect(viewModel.toastMessage == CoachBindStrings.text("coach.bind.accepted"))
  let recorded = await repository.acceptedRequests
  #expect(recorded[0].skip == true)
  #expect(recorded[0].reason == "老学员")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptNeverSendsReasonOnEvaluationBranchEvenIfProvided() async {
  let repository = StubBindQueueRepository()
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()
  let item = viewModel.items[0]

  // UI-layer guarantee for the zod superRefine: reason dropped off the
  // evaluation branch.
  _ = await viewModel.accept(item, skipEvaluation: false, skipReason: "误传")

  let recorded = await repository.acceptedRequests
  #expect(recorded[0].reason == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func blankSkipReasonIsDroppedNotSentEmpty() async {
  let repository = StubBindQueueRepository()
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()
  let item = viewModel.items[0]

  _ = await viewModel.accept(item, skipEvaluation: true, skipReason: "   ")

  let recorded = await repository.acceptedRequests
  #expect(recorded[0].reason == nil)
}

// MARK: - 4xx machine codes → banner + refresh (D12)

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptMachineCodeErrorsBannerAndForceRefresh() async {
  let cases: [(CoachBindQueueError, String)] = [
    (.expired, CoachBindStrings.text("coach.bind.error.expired")),
    (.notPending, CoachBindStrings.text("coach.bind.error.processed")),
    (.notFound, CoachBindStrings.text("coach.bind.error.processed")),
    (.alreadyBound, CoachBindStrings.text("coach.bind.error.alreadyBound")),
  ]
  for (error, expectedBanner) in cases {
    let repository = StubBindQueueRepository(acceptError: error)
    let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
    await viewModel.loadIfNeeded()
    let fetchesBefore = await repository.fetchCount

    let accepted = await viewModel.accept(
      viewModel.items[0], skipEvaluation: false, skipReason: nil)

    #expect(!accepted)
    #expect(viewModel.bannerMessage == expectedBanner)
    let fetchesAfter = await repository.fetchCount
    #expect(fetchesAfter == fetchesBefore + 1)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rejectRemovesItemSilently() async {
  let repository = StubBindQueueRepository()
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()
  let item = viewModel.items[0]

  let rejected = await viewModel.reject(item)

  #expect(rejected)
  #expect(viewModel.items.isEmpty)
  let rejectedIDs = await repository.rejectedRequestIDs
  #expect(rejectedIDs == [item.id])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rejectExpiredBannerAndRefresh() async {
  let repository = StubBindQueueRepository(rejectError: CoachBindQueueError.expired)
  let viewModel = BindQueueViewModel(repository: repository, now: { BindQueueFixtures.now })
  await viewModel.loadIfNeeded()

  let rejected = await viewModel.reject(viewModel.items[0])

  #expect(!rejected)
  #expect(viewModel.bannerMessage == CoachBindStrings.text("coach.bind.error.expired"))
}

// MARK: - 9-item summary display mapping

@available(iOS 17.0, macOS 14.0, *)
@Test func ageDerivesFromBirthDateClientSide() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
  let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11))!

  #expect(
    CoachOnboardingDisplay.age(birthDate: "2001-03-15", now: now, calendar: calendar) == 25)
  #expect(
    CoachOnboardingDisplay.age(birthDate: "2001-07-01", now: now, calendar: calendar) == 24)
  #expect(CoachOnboardingDisplay.age(birthDate: nil, now: now, calendar: calendar) == nil)
  #expect(CoachOnboardingDisplay.age(birthDate: "垃圾", now: now, calendar: calendar) == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func oneRMTrioStripsTrailingZeros() {
  let text = CoachOnboardingDisplay.oneRMTrio(
    squat: 180,
    bench: Decimal(string: "92.50")!,
    deadlift: nil
  )
  #expect(text == "S:180 B:92.5 D:— (kg)")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func trainingYearsNotchLabels() {
  #expect(
    CoachOnboardingDisplay.trainingYearsText(0)
      == CoachBindStrings.text("coach.bind.training.lessThanOne"))
  #expect(CoachOnboardingDisplay.trainingYearsText(3) == CoachBindStrings.trainingYears(3))
  #expect(
    CoachOnboardingDisplay.trainingYearsText(10)
      == CoachBindStrings.text("coach.bind.training.tenPlus"))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func waitingTextScalesWithElapsedTime() {
  let base = BindQueueFixtures.now
  #expect(
    CoachOnboardingDisplay.waitingText(since: base.addingTimeInterval(-300), now: base)
      == CoachBindStrings.waitingMinutes(5))
  #expect(
    CoachOnboardingDisplay.waitingText(
      since: base.addingTimeInterval(-(2 * 3_600 + 14 * 60)), now: base)
      == CoachBindStrings.waitingHoursMinutes(2, 14))
  #expect(
    CoachOnboardingDisplay.waitingText(since: base.addingTimeInterval(-3 * 86_400), now: base)
      == CoachBindStrings.waitingDays(3))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func expiringSoonOnlyWithin24Hours() {
  let now = BindQueueFixtures.now
  #expect(
    CoachOnboardingDisplay.isExpiringSoon(
      expiredAt: now.addingTimeInterval(23 * 3_600), now: now))
  #expect(
    !CoachOnboardingDisplay.isExpiringSoon(
      expiredAt: now.addingTimeInterval(25 * 3_600), now: now))
  #expect(
    !CoachOnboardingDisplay.isExpiringSoon(
      expiredAt: now.addingTimeInterval(-60), now: now))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func degradedSummaryReportsIncomplete() {
  let onboarding = BindQueueFixtures.onboarding(completed: false)
  #expect(!onboarding.completed)
  #expect(onboarding.gender == nil)
  #expect(onboarding.uploadCount == 0)
}
