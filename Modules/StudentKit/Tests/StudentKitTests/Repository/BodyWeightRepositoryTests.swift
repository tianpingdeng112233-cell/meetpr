import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func bodyWeight404FallsBackToLegacyProfileSave() async throws {
  let requests = WeightRequests()
  let api = APIClient(transport: { request in
    await requests.append(request)
    if request.url?.path.contains("body-weights") == true {
      return APIResponse(data: Data("missing route".utf8), statusCode: 404)
    }
    return APIResponse(
      data: Data(
        """
        {"user_id":"00000000-0000-0000-0000-000000000001","weight_kg":"83.25",
         "created_at":"2026-11-08T00:00:00Z","updated_at":"2026-11-08T00:00:00Z"}
        """.utf8), statusCode: 200)
  })
  let repo = BackendOnboardingRepository(api: api, session: WeightSession())
  let current = try await repo.saveTodaysWeight(Decimal(string: "83.25") ?? 0)
  #expect(current == Decimal(string: "83.25"))
  let sent = await requests.values
  #expect(sent.count == 2)
  #expect(sent.first?.httpMethod == "PUT")
  #expect(sent.last?.url?.path.hasSuffix("/students/me/onboarding") == true)
  let body = try #require(sent.last?.httpBody)
  #expect(
    try JSONSerialization.jsonObject(with: body) as? [String: String] == ["weight_kg": "83.25"])
}

@Test func bodyWeightWriteUsesLocalCalendarDayAtSaveAndExactWireShape() async throws {
  let requests = WeightRequests()
  let instant = try Date("2026-11-08T01:30:00Z", strategy: .iso8601)
  let zone = try #require(TimeZone(secondsFromGMT: -8 * 3600))
  let api = APIClient(transport: { request in
    await requests.append(request)
    return APIResponse(
      data: Data(
        #"{"record":{"recorded_on":"2026-11-07","weight_kg":"83.00"},"current_weight_kg":"84.00"}"#
          .utf8), statusCode: 200)
  })
  let repo = BackendOnboardingRepository(
    api: api, session: WeightSession(), now: { instant }, timeZone: { zone })
  #expect(try await repo.saveTodaysWeight(83) == 84)
  let sent = await requests.values
  #expect(sent.count == 1)
  #expect(sent.first?.url?.path.hasSuffix("/students/me/body-weights/2026-11-07") == true)
  let body = try #require(sent.first?.httpBody)
  #expect(
    try JSONSerialization.jsonObject(with: body) as? [String: String] == ["weight_kg": "83.00"])
}

@Test(arguments: [400, 401, 403, 500])
func bodyWeightOtherErrorsNeverFallBack(status: Int) async {
  let requests = WeightRequests()
  let api = APIClient(transport: { request in
    await requests.append(request)
    return APIResponse(data: Data(), statusCode: status)
  })
  let repo = BackendOnboardingRepository(api: api, session: WeightSession())
  await #expect(throws: (any Error).self) { try await repo.saveTodaysWeight(83) }
  #expect(await requests.values.count == 1)
}

@Test func bodyWeightReadAndDeleteUseContractAndRefreshWithoutCache() async throws {
  let requests = WeightRequests()
  let api = APIClient(transport: { request in
    await requests.append(request)
    if request.httpMethod == "DELETE" {
      return APIResponse(data: Data(#"{"current_weight_kg":null}"#.utf8), statusCode: 200)
    }
    let count = await requests.values.count
    return APIResponse(
      data: Data(
        (count == 1
          ? #"{"records":[{"recorded_on":"2026-10-09","weight_kg":"83.25"}]}"#
          : #"{"records":[]}"#).utf8), statusCode: 200)
  })
  let repo = BackendOnboardingRepository(api: api, session: WeightSession())
  let records = try await repo.fetchBodyWeights()
  #expect(
    records == [BodyWeightRecord(recordedOn: "2026-10-09", weightKg: Decimal(string: "83.25") ?? 0)]
  )
  #expect(try await repo.deleteBodyWeight(on: "2026-10-09") == nil)
  #expect(try await repo.fetchBodyWeights().isEmpty)
  let sent = await requests.values
  #expect(sent.map(\.httpMethod) == ["GET", "DELETE", "GET"])
  #expect(sent[1].url?.path.hasSuffix("/students/me/body-weights/2026-10-09") == true)
}

private actor WeightRequests {
  var values: [URLRequest] = []
  func append(_ request: URLRequest) { values.append(request) }
}

private struct WeightSession: SessionStateReader {
  func accessToken() async throws -> String { "test-token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}

@Test func bodyWeightDemoMirrorsLegacyOnboardingRecordingWithoutSpuriousRecords() async throws {
  let profile = OnboardingFixtures.serverProfile()
  let now = profile.updatedAt.addingTimeInterval(2 * 86_400)
  let repo = InMemoryOnboardingRepository(studentId: profile.userId, seed: profile, now: { now })
  var patch = OnboardingPatch()
  patch.weightKg = .value(profile.weightKg ?? 83)
  _ = try await repo.upsert(patch)
  #expect(try await repo.fetchBodyWeights().count == 1)
  patch.weightKg = .value(88)
  _ = try await repo.upsert(patch)
  #expect(try await repo.fetchBodyWeights().count == 2)
  #expect(try await repo.fetchBodyWeights().last?.weightKg == 88)
}

@MainActor
@Test func bodyWeightMissingEndpointShowsFailureAndDashWithoutUsingProfileValue() async {
  let repo = BackendOnboardingRepository(
    api: APIClient(transport: { _ in APIResponse(data: Data(), statusCode: 404) }),
    session: WeightSession())
  let model = BodyWeightViewModel(studentID: UUID(), repository: repo)
  await model.load()
  #expect(model.isFailed)
  #expect(!model.isLoaded)
  #expect(model.menuValue == "—")
}

@Test func bodyWeightDateHonorsBothTimezoneExtremesBeforeTrainingDayBoundary() throws {
  let now = try Date("2026-11-08T11:30:00Z", strategy: .iso8601)
  let east = try #require(TimeZone(secondsFromGMT: 14 * 3600))
  let west = try #require(TimeZone(secondsFromGMT: -12 * 3600))
  #expect(BodyWeightDay.string(from: now, timeZone: east) == "2026-11-09")
  #expect(BodyWeightDay.string(from: now, timeZone: west) == "2026-11-07")
}
