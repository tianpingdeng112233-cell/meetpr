import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test(arguments: ["feedback", "three-consecutive", "abandoned-tail", "all-completed", "no-plans"])
func handoffColdStartUsesServerCurrentInsteadOfLatestPublished(fixtureName: String) async throws {
  let fixture = try Data(
    contentsOf: #require(
      Bundle.module.url(
        forResource: fixtureName, withExtension: "json", subdirectory: "PlanHandoff")))
  let response = try MeetPRCodec.decoder.decode(PlansResponseDTO.self, from: fixture)
  let object = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
  let expected = (object["current_plan_id"] as? String).flatMap(UUID.init(uuidString:))
  let studentID = response.plans.first?.traineeID ?? UUID()
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    let path = request.url?.path ?? ""
    if path.hasSuffix("/plan-handoff") || path.hasSuffix("/plans") {
      return APIResponse(data: fixture, statusCode: 200)
    }
    if let plan = response.plans.first(where: {
      path.lowercased().hasSuffix($0.id.uuidString.lowercased())
    }) {
      return APIResponse(
        data: try MeetPRCodec.encoder.encode(PlanWithChildrenDTO(plan: plan, days: [])),
        statusCode: 200)
    }
    return APIResponse(data: Data(#"{"exercises":[]}"#.utf8), statusCode: 200)
  }
  let cache = StudentPlanCache(directory: directory)
  // Old v3 cache can point to the latest published cycle from the previous app.
  try await cache.save(plan: StudentDemoSeed.makePlanView(), studentID: studentID)
  let repository: any StudentPlanRepository = BackendStudentPlanRepository(
    api: api, session: HandoffSession(), cache: cache,
    catalogCache: ExerciseCatalogCache(directory: directory))
  #expect(try await repository.fetchCurrentPlan(studentID: studentID)?.cycleID == expected)
  if fixtureName == "feedback" {
    let handoff = try await repository.fetchPlanHandoff(studentID: studentID)
    #expect(handoff?.plans.first?.completedTrainingDays == 16)
    #expect(handoff?.plans.last?.status == .upcoming)
  }
}

private struct HandoffSession: SessionStateReader {
  func accessToken() async throws -> String { "fixture-token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}

@Test(arguments: [404, 500])
func handoffUnavailableFallsBackToLegacyPublishedList(status: Int) async throws {
  let fixture = try Data(
    contentsOf: #require(
      Bundle.module.url(
        forResource: "feedback", withExtension: "json", subdirectory: "PlanHandoff")))
  let plans = try MeetPRCodec.decoder.decode(PlansResponseDTO.self, from: fixture).plans
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    let path = request.url?.path ?? ""
    if path.hasSuffix("/plan-handoff") { return APIResponse(data: Data(), statusCode: status) }
    if path.hasSuffix("/plans") {
      let query = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
      #expect(query?.queryItems?.contains { $0.name == "include_all" } != true)
      return APIResponse(data: fixture, statusCode: 200)
    }
    if let plan = plans.first(where: { path.lowercased().hasSuffix($0.id.uuidString.lowercased()) })
    {
      return APIResponse(
        data: try MeetPRCodec.encoder.encode(PlanWithChildrenDTO(plan: plan, days: [])),
        statusCode: 200)
    }
    return APIResponse(data: Data(#"{"exercises":[]}"#.utf8), statusCode: 200)
  }
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let repo = BackendStudentPlanRepository(
    api: api, session: HandoffSession(),
    cache: StudentPlanCache(directory: directory),
    catalogCache: ExerciseCatalogCache(directory: directory))
  #expect(try await repo.fetchCurrentPlan(studentID: plans[0].traineeID)?.cycleID == plans[1].id)
}

@Test func handoffOfflineDecodesOldV3CacheAndKeepsItsOriginalDays() async throws {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let plan = StudentDemoSeed.makePlanView()
  var payload = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(plan)) as? [String: Any])
  payload.removeValue(forKey: "handoff")
  let studentID = StudentDemoSeed.studentID
  try JSONSerialization.data(withJSONObject: payload).write(
    to: directory.appending(
      path: "student-\(studentID.uuidString)-plan-v3.json"))
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    throw URLError(.notConnectedToInternet)
  }
  let repo = BackendStudentPlanRepository(
    api: api, session: HandoffSession(), cache: StudentPlanCache(directory: directory))
  #expect(try await repo.fetchCurrentPlan(studentID: studentID) == plan)
}

@Test func handoffCompletionAndUndoRefreshUseServerResultWithoutClientSorting() async throws {
  let fixture = try Data(
    contentsOf: #require(
      Bundle.module.url(
        forResource: "feedback", withExtension: "json", subdirectory: "PlanHandoff")))
  let transport = try HandoffMutationTransport(fixture: fixture)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    try await transport.respond(path: request.url?.path ?? "", method: request.httpMethod ?? "GET")
  }
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let repo: any StudentPlanRepository = BackendStudentPlanRepository(
    api: api, session: HandoffSession(),
    cache: StudentPlanCache(directory: directory),
    catalogCache: ExerciseCatalogCache(directory: directory))
  let studentID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000003"))
  let oldID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
  let nextID = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000002"))
  let dayID = UUID()
  #expect(try await repo.fetchCurrentPlan(studentID: studentID)?.cycleID == oldID)
  _ = try await repo.completeDay(id: dayID, studentID: studentID)
  #expect(try await repo.refreshCurrentPlan(studentID: studentID)?.cycleID == nextID)
  #expect(try await repo.refreshCurrentPlan(studentID: studentID)?.cycleID == nextID)
  try await repo.undoDayCompletion(id: dayID, studentID: studentID)
  #expect(try await repo.refreshCurrentPlan(studentID: studentID)?.cycleID == oldID)
  #expect(await transport.mutatedDays == [dayID, dayID])
}

private actor HandoffMutationTransport {
  let fixture: Data
  let plans: [PlanDTO]
  var advanced = false
  var mutatedDays: [UUID] = []
  init(fixture: Data) throws {
    self.fixture = fixture
    plans = try MeetPRCodec.decoder.decode(PlansResponseDTO.self, from: fixture).plans
  }
  func respond(path: String, method: String) throws -> APIResponse {
    if path.hasSuffix("/complete"),
      let dayID = UUID(uuidString: String(path.split(separator: "/").dropLast().last ?? ""))
    {
      mutatedDays.append(dayID)
      advanced = method == "POST"
      if !advanced { return APIResponse(data: Data(), statusCode: 204) }
      let body: [String: Any] = [
        "id": UUID().uuidString, "plan_day_id": dayID.uuidString,
        "student_id": plans[0].traineeID.uuidString, "source": "manual",
        "completed_at": "2026-11-16T12:00:00Z",
      ]
      return APIResponse(data: try JSONSerialization.data(withJSONObject: body), statusCode: 200)
    }
    if path.hasSuffix("/plan-handoff") {
      var object = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
      object["current_plan_id"] = plans[advanced ? 1 : 0].id.uuidString
      return APIResponse(data: try JSONSerialization.data(withJSONObject: object), statusCode: 200)
    }
    if let plan = plans.first(where: { path.lowercased().hasSuffix($0.id.uuidString.lowercased()) })
    {
      return APIResponse(
        data: try MeetPRCodec.encoder.encode(PlanWithChildrenDTO(plan: plan, days: [])),
        statusCode: 200)
    }
    return APIResponse(data: Data(#"{"exercises":[]}"#.utf8), statusCode: 200)
  }
}
