import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

private let coachId = UUID(uuidString: "0e000000-0000-0000-0000-000000000001")!
private let fixedNow = Date(timeIntervalSince1970: 1_780_000_000)

private func makeCode(
  id: Int,
  type: InviteCodeType,
  usedCount: Int = 0,
  expiresAt: Date? = nil,
  revokedAt: Date? = nil,
  createdAt: Date = fixedNow
) -> InviteCode {
  InviteCode(
    id: UUID(uuidString: String(format: "0e000000-0000-0000-0000-%012d", id))!,
    coachId: coachId,
    code: "ABCDEFGHJK",
    type: type,
    maxUses: type == .singleUse ? 1 : nil,
    usedCount: usedCount,
    expiresAt: expiresAt,
    revokedAt: revokedAt,
    label: nil,
    createdAt: createdAt
  )
}

// MARK: - D7 status derivation (read-time, injected clock)

@Test func statusIsActiveForUnusedSingleUse() {
  let status = InviteCodeStatus.status(of: makeCode(id: 1, type: .singleUse), now: fixedNow)
  #expect(status == .active)
  #expect(status.label == "待用")
}

@Test func statusIsUsedWhenSingleUseBudgetExhausted() {
  let code = makeCode(id: 2, type: .singleUse, usedCount: 1)
  #expect(InviteCodeStatus.status(of: code, now: fixedNow) == .used)
}

@Test func statusCountsRemainingDaysForTimeLimited() {
  let code = makeCode(
    id: 3, type: .timeLimited, expiresAt: fixedNow.addingTimeInterval(6 * 86_400))
  let status = InviteCodeStatus.status(of: code, now: fixedNow)
  #expect(status == .expiringIn(days: 6))
  #expect(status.label == "6 天后过期")
}

@Test func statusFlipsToExpiredAtBoundary() {
  let expiry = fixedNow.addingTimeInterval(3_600)
  let code = makeCode(id: 4, type: .timeLimited, expiresAt: expiry)
  // One second before expiry → still live (rounded up to 1 day).
  #expect(
    InviteCodeStatus.status(of: code, now: expiry.addingTimeInterval(-1))
      == .expiringIn(days: 1))
  // At/after expiry → expired (matches backend `expires_at > now()` guard).
  #expect(InviteCodeStatus.status(of: code, now: expiry) == .expired)
}

@Test func revokedWinsOverEverything() {
  let code = makeCode(
    id: 5, type: .singleUse, usedCount: 1, expiresAt: fixedNow.addingTimeInterval(-86_400),
    revokedAt: fixedNow)
  #expect(InviteCodeStatus.status(of: code, now: fixedNow) == .revoked)
}

@Test func personalPermanentNeverExpiresOrExhausts() {
  let code = makeCode(id: 6, type: .personalPermanent, usedCount: 99)
  #expect(InviteCodeStatus.status(of: code, now: fixedNow) == .active)
}

// MARK: - View model behavior

@MainActor
private func makeViewModel(seed: [InviteCode] = []) -> (
  InviteCodesViewModel, InMemoryInviteCodeRepository
) {
  let repo = InMemoryInviteCodeRepository(coachId: coachId, seed: seed, now: { fixedNow })
  return (InviteCodesViewModel(repository: repo, now: { fixedNow }), repo)
}

@MainActor
@Test func emptyStateHasNoPersonalCode() async {
  let (viewModel, _) = makeViewModel()
  await viewModel.loadIfNeeded()
  #expect(viewModel.activePersonalCode == nil)
  #expect(viewModel.liveSecondaryCodes.isEmpty)
}

@MainActor
@Test func generatePersonalCodeShowsUpAfterReload() async {
  let (viewModel, _) = makeViewModel()
  await viewModel.loadIfNeeded()

  await viewModel.generatePersonalCode()

  #expect(viewModel.activePersonalCode != nil)
  #expect(viewModel.activePersonalCode?.usedCount == 0)
}

@MainActor
@Test func regenerateRevokesOldPersonalCode() async {
  let (viewModel, _) = makeViewModel()
  await viewModel.loadIfNeeded()
  await viewModel.generatePersonalCode()
  let first = viewModel.activePersonalCode

  await viewModel.generatePersonalCode()
  let second = viewModel.activePersonalCode

  #expect(second != nil)
  #expect(second?.id != first?.id)  // old one revoked, new one active
}

@MainActor
@Test func timeLimitedCreationCarriesExpiry() async {
  let (viewModel, _) = makeViewModel()
  await viewModel.loadIfNeeded()

  await viewModel.createTimeLimitedCode(label: " 馆活动周 ", expiresInDays: 7)

  let code = viewModel.liveSecondaryCodes.first
  #expect(code?.type == .timeLimited)
  #expect(code?.label == "馆活动周")  // trimmed
  #expect(code?.expiresAt == fixedNow.addingTimeInterval(7 * 86_400))
}

@MainActor
@Test func revokeMovesCodeToDefunctSection() async {
  let (viewModel, _) = makeViewModel()
  await viewModel.loadIfNeeded()
  await viewModel.createSingleUseCode(label: nil)
  guard let code = viewModel.liveSecondaryCodes.first else {
    Issue.record("expected a live code")
    return
  }

  await viewModel.revoke(id: code.id)

  #expect(viewModel.liveSecondaryCodes.isEmpty)
  #expect(viewModel.defunctSecondaryCodes.first?.id == code.id)
}

@MainActor
@Test func demoSeedHasPersonalPlusTwoSecondaryCodes() async {
  let (viewModel, _) = makeViewModel(
    seed: InMemoryInviteCodeRepository.demoSeed(coachId: coachId, now: fixedNow))
  await viewModel.loadIfNeeded()

  #expect(viewModel.activePersonalCode?.usedCount == 23)
  #expect(viewModel.liveSecondaryCodes.count == 2)
  let statuses = viewModel.liveSecondaryCodes.map { viewModel.status(of: $0) }
  #expect(statuses.contains(.active))
  #expect(statuses.contains(.expiringIn(days: 6)))
}

// MARK: - InMemory semantics

@Test func inMemoryRevokeIsIdempotent() async throws {
  let repo = InMemoryInviteCodeRepository(coachId: coachId, now: { fixedNow })
  let code = try await repo.createCode(type: .singleUse, label: nil, expiresInDays: nil)

  try await repo.revokeCode(id: code.id)
  let firstRevokedAt = try await repo.listCodes().first?.revokedAt
  try await repo.revokeCode(id: code.id)
  let secondRevokedAt = try await repo.listCodes().first?.revokedAt

  #expect(firstRevokedAt != nil)
  #expect(firstRevokedAt == secondRevokedAt)
}

@Test func inMemoryRevokeUnknownIdThrowsNotFound() async {
  let repo = InMemoryInviteCodeRepository(coachId: coachId)
  await #expect(throws: BindRequestError.notFound) {
    try await repo.revokeCode(id: UUID())
  }
}

@Test func inMemoryListIsNewestFirst() async throws {
  let repo = InMemoryInviteCodeRepository(coachId: coachId, now: { fixedNow })
  let first = try await repo.createCode(type: .singleUse, label: "a", expiresInDays: nil)
  let second = try await repo.createCode(type: .singleUse, label: "b", expiresInDays: nil)

  let listed = try await repo.listCodes()
  #expect(listed.map(\.id) == [second.id, first.id])
}
