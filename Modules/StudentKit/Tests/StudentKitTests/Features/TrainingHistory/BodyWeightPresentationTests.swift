import Foundation
import Testing

@testable import StudentKit

@Test func bodyWeightPresentationSortsHistoryFiltersChartAndKeepsLatestHeadline() throws {
  let now = try #require(DateOnly.date(from: "2026-11-08"))
  let records = [
    BodyWeightRecord(recordedOn: "2026-11-08", weightKg: 83),
    BodyWeightRecord(recordedOn: "2026-08-01", weightKg: 86),
    BodyWeightRecord(recordedOn: "2026-10-20", weightKg: Decimal(string: "83.75") ?? 0),
  ]
  let month = BodyWeightPresentation(records: records, range: .thirtyDays, now: now)
  #expect(month.records.map(\.recordedOn) == ["2026-11-08", "2026-10-20", "2026-08-01"])
  #expect(month.points.map(\.recordedOn) == ["2026-10-20", "2026-11-08"])
  #expect(month.currentKg == 83)
  #expect(month.deltaKg == Decimal(string: "-0.75"))
  #expect(month.hasToday)
  #expect(month.state == .chart)
  let all = BodyWeightPresentation(records: records, range: .all, now: now)
  #expect(all.points.count == 3)
  #expect(all.deltaKg == -3)
}

@MainActor
@Test func bodyWeightPageDeletesLatestThenLastAndProfileBecomesEmpty() async throws {
  let profile = OnboardingFixtures.serverProfile()
  let tomorrow = profile.updatedAt.addingTimeInterval(2 * 86_400)
  let repo = InMemoryOnboardingRepository(
    studentId: profile.userId, seed: profile, now: { tomorrow })
  let model = BodyWeightViewModel(studentID: profile.userId, repository: repo, now: { tomorrow })
  await model.load()
  #expect(model.records.count == 1)
  #expect(model.presentation.state == .single)
  _ = try await repo.saveTodaysWeight(84)
  _ = try await repo.saveTodaysWeight(85)
  await model.load()
  #expect(model.records.count == 2)
  #expect(model.presentation.currentKg == 85)
  let latest = try #require(model.presentation.records.first)
  #expect(await model.delete(latest))
  #expect(model.presentation.currentKg == profile.weightKg)
  let last = try #require(model.records.first)
  #expect(await model.delete(last))
  #expect(model.presentation.state == .empty)
  #expect(model.presentation.currentKg == nil)
  #expect(try await repo.fetchProfile(studentId: profile.userId)?.weightKg == nil)
}

@MainActor
@Test func bodyWeightMenuFormatsTwoDecimalsAndMissingEndpointCanRetry() async throws {
  let repo = WeightPageRepository()
  let model = BodyWeightViewModel(studentID: UUID(), repository: repo)
  #expect(model.menuValue == nil)
  await model.load()
  #expect(model.menuValue == "83.00 kg")
  await repo.setFailed(true)
  await model.load()
  #expect(model.isFailed)
  #expect(model.menuValue == "—")
  await repo.setFailed(false)
  await model.load()
  #expect(!model.isFailed)
  #expect(model.menuValue == "83.00 kg")
}

private actor WeightPageRepository: BodyWeightRepository {
  var failed = false
  func setFailed(_ value: Bool) { failed = value }
  func fetchBodyWeights() throws -> [BodyWeightRecord] {
    if failed { throw BodyWeightError.unavailable }
    return [BodyWeightRecord(recordedOn: "2026-11-08", weightKg: 83)]
  }
  func saveTodaysWeight(_ kilograms: Decimal) throws -> Decimal? { kilograms }
  func deleteBodyWeight(on date: String) throws -> Decimal? {
    if failed { throw BodyWeightError.unavailable }
    return nil
  }
}

@Test func bodyWeightPresentationCoversEmptySingleOldAndNinetyDayWindows() throws {
  let now = try #require(DateOnly.date(from: "2026-11-08"))
  let empty = BodyWeightPresentation(records: [], range: .all, now: now)
  #expect(empty.state == .empty)
  #expect(empty.currentKg == nil && empty.deltaKg == nil && !empty.hasToday)
  let old = BodyWeightRecord(recordedOn: "2026-09-01", weightKg: 85)
  let single = BodyWeightPresentation(records: [old], range: .ninetyDays, now: now)
  #expect(single.state == .single)
  #expect(single.points == [old])
  #expect(single.deltaKg == nil && !single.hasToday)
  let month = BodyWeightPresentation(records: [old], range: .thirtyDays, now: now)
  #expect(month.state == .empty && month.points.isEmpty)
  #expect(month.currentKg == 85 && month.records == [old])
  let edge = [
    BodyWeightRecord(recordedOn: "2026-10-09", weightKg: 86),
    BodyWeightRecord(recordedOn: "2026-10-10", weightKg: 85),
  ]
  #expect(BodyWeightPresentation(records: edge, range: .thirtyDays, now: now).points == [edge[1]])
}

@MainActor
@Test func bodyWeightFailedDeletePreservesRecordsAndCurrentWeight() async {
  let repo = WeightPageRepository()
  let model = BodyWeightViewModel(studentID: UUID(), repository: repo)
  await model.load()
  await repo.setFailed(true)
  let record = BodyWeightRecord(recordedOn: "2026-11-08", weightKg: 83)
  #expect(await model.delete(record) == false)
  #expect(model.deletionFailed)
  #expect(model.records == [record])
  #expect(model.presentation.currentKg == 83)
}

@MainActor
@Test func bodyWeightRetryAlwaysTargetsTheRecordWhoseDeletionFailed() async throws {
  let repo = WeightRetryRepository()
  let model = BodyWeightViewModel(studentID: UUID(), repository: repo)
  await model.load()
  let record = try #require(model.records.first)
  #expect(await model.delete(record) == false)
  // The view may select and cancel another record; retry accepts no replacement target.
  #expect(await model.retryDelete())
  #expect(model.records.map(\.recordedOn) == ["2026-11-08"])
  #expect(await repo.deletedDates == ["2026-11-07", "2026-11-07"])
}

private actor WeightRetryRepository: BodyWeightRepository {
  var records = [
    BodyWeightRecord(recordedOn: "2026-11-07", weightKg: 82),
    BodyWeightRecord(recordedOn: "2026-11-08", weightKg: 83),
  ]
  var deletedDates: [String] = []
  func fetchBodyWeights() -> [BodyWeightRecord] { records }
  func saveTodaysWeight(_ kilograms: Decimal) -> Decimal? { kilograms }
  func deleteBodyWeight(on date: String) throws -> Decimal? {
    deletedDates.append(date)
    if deletedDates.count == 1 { throw BodyWeightError.unavailable }
    records.removeAll { $0.recordedOn == date }
    return records.last?.weightKg
  }
}
