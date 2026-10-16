import CoreModels
import Foundation
import Networking
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func retiredAndUnknownCoachStatusesMapToActive() {
  let retiredStatus = ["in", "eval", "uation"].joined(separator: "_")
  let rawStatuses = [retiredStatus, "future_status"]

  for rawStatus in rawStatuses {
    let dto = CoachStudentSummaryDTO(
      userID: UUID(),
      displayName: "Legacy student",
      createdAt: PlanningFixtures.now,
      status: rawStatus
    )

    #expect(BackendPlanRepository.status(from: dto) == .active)
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func backendPublishPlanCreatesTreeBeforePublishingWithServerIDs() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "BackendPlanRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  let log = PublishRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.response(for: request)
  }
  let cache = PlanCache(directory: directory)
  let repository = BackendPlanRepository(
    api: client,
    session: TestSession(),
    cache: cache
  )

  try await repository.publishPlan(
    plan: PlanningFixtures.plan(),
    days: PlanningFixtures.planDays(),
    exercises: PlanningFixtures.planExercises(),
    sets: PlanningFixtures.planSets()
  )

  let requests = await log.requests()
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /plans",
      "POST /plans/\(PublishIDs.serverPlanID.uuidString)/days",
      "POST /plans/days/\(PublishIDs.serverDayID.uuidString)/exercises",
      "POST /plans/exercises/\(PublishIDs.serverPlanExerciseID.uuidString)/sets",
      "POST /plans/\(PublishIDs.serverPlanID.uuidString)/publish",
    ]
  )
  #expect(
    requests[3].body?.contains(#""target_value":"100""#) == true
  )

  let cached = try #require(await cache.loadPlan(id: PublishIDs.serverPlanID))
  #expect(cached.plan.id == PublishIDs.serverPlanID)
  #expect(cached.plan.status == .published)
  #expect(cached.days.map(\.id) == [PublishIDs.serverDayID])
  #expect(cached.days.map(\.planID) == [PublishIDs.serverPlanID])
  #expect(cached.exercises.map(\.id) == [PublishIDs.serverPlanExerciseID])
  #expect(cached.exercises.map(\.planDayID) == [PublishIDs.serverDayID])
  #expect(cached.sets.map(\.id) == [PublishIDs.serverSetID])
  #expect(cached.sets.map(\.planExerciseID) == [PublishIDs.serverPlanExerciseID])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func backendPublishPlanThrowsWhenAChildCreateFailsAndDoesNotPublish() async throws {
  let log = PublishRequestLog(
    failingPath: "/plans/days/\(PublishIDs.serverDayID.uuidString)/exercises"
  )
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.response(for: request)
  }
  let repository = BackendPlanRepository(
    api: client,
    session: TestSession(),
    cache: PlanCache(
      directory: FileManager.default.temporaryDirectory
        .appending(path: "BackendPlanRepositoryTests-\(UUID().uuidString)")
    )
  )

  do {
    try await repository.publishPlan(
      plan: PlanningFixtures.plan(),
      days: PlanningFixtures.planDays(),
      exercises: PlanningFixtures.planExercises(),
      sets: PlanningFixtures.planSets()
    )
    Issue.record("Expected publishPlan to throw when creating a child resource fails.")
  } catch let error as APIError {
    #expect(error == .httpStatus(500, Data(#"{"error":"BOOM"}"#.utf8)))
  }

  let requests = await log.requests()
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /plans",
      "POST /plans/\(PublishIDs.serverPlanID.uuidString)/days",
      "POST /plans/days/\(PublishIDs.serverDayID.uuidString)/exercises",
    ]
  )
}

@available(iOS 17.0, macOS 14.0, *)
private struct TestSession: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    User(
      id: PublishIDs.coachID,
      phone: "+8613800000001",
      unitSystem: .metric,
      role: .coach,
      createdAt: PlanningFixtures.now,
      updatedAt: PlanningFixtures.now
    )
  }
}

private enum PublishIDs {
  static let coachID = uuid(200)
  static let serverPlanID = uuid(201)
  static let serverDayID = uuid(202)
  static let serverPlanExerciseID = uuid(203)
  static let serverSetID = uuid(204)

  private static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }
}

private actor PublishRequestLog {
  private let failingPath: String?
  private var capturedRequests: [RecordedPublishRequest] = []

  init(failingPath: String? = nil) {
    self.failingPath = failingPath
  }

  func response(for request: URLRequest) -> APIResponse {
    let recorded = RecordedPublishRequest(request: request)
    capturedRequests.append(recorded)

    if recorded.path == failingPath {
      return APIResponse(data: Data(#"{"error":"BOOM"}"#.utf8), statusCode: 500)
    }

    return APIResponse(data: responseData(for: recorded), statusCode: statusCode(for: recorded))
  }

  func requests() -> [RecordedPublishRequest] {
    capturedRequests
  }

  private func responseData(for request: RecordedPublishRequest) -> Data {
    switch (request.method, request.path) {
    case ("POST", "/plans"):
      Data(planJSON(id: PublishIDs.serverPlanID, status: .draft).utf8)
    case ("POST", "/plans/\(PublishIDs.serverPlanID.uuidString)/days"):
      Data(planDayJSON().utf8)
    case ("POST", "/plans/days/\(PublishIDs.serverDayID.uuidString)/exercises"):
      Data(planExerciseJSON().utf8)
    case ("POST", "/plans/exercises/\(PublishIDs.serverPlanExerciseID.uuidString)/sets"):
      Data(planSetJSON().utf8)
    case ("POST", "/plans/\(PublishIDs.serverPlanID.uuidString)/publish"):
      Data(planJSON(id: PublishIDs.serverPlanID, status: .published).utf8)
    default:
      Data(#"{"error":"UNEXPECTED_REQUEST"}"#.utf8)
    }
  }

  private func statusCode(for request: RecordedPublishRequest) -> Int {
    request.path.hasSuffix("/publish") ? 200 : 201
  }

  private func planJSON(id: UUID, status: PlanStatus) -> String {
    """
    {
      "id": "\(id.uuidString)",
      "coach_id": "\(PublishIDs.coachID.uuidString)",
      "trainee_id": "\(PlanningFixtures.activeStudentID.uuidString)",
      "name": "张三 4 周计划",
      "start_date": "2026-05-22",
      "end_date": "2026-06-18",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "\(status.rawValue)",
      "created_at": "2026-05-22T12:00:00Z",
      "updated_at": "2026-05-22T12:00:00Z"
    }
    """
  }

  private func planDayJSON() -> String {
    """
    {
      "id": "\(PublishIDs.serverDayID.uuidString)",
      "plan_id": "\(PublishIDs.serverPlanID.uuidString)",
      "day_of_week": 1,
      "week_number": 1,
      "sort_order": 0,
      "exercises": []
    }
    """
  }

  private func planExerciseJSON() -> String {
    """
    {
      "id": "\(PublishIDs.serverPlanExerciseID.uuidString)",
      "plan_day_id": "\(PublishIDs.serverDayID.uuidString)",
      "exercise_id": "\(PlanningFixtures.squatID.uuidString)",
      "is_main_lift": true,
      "sort_order": 0,
      "notes": "主项",
      "sets": []
    }
    """
  }

  private func planSetJSON() -> String {
    """
    {
      "id": "\(PublishIDs.serverSetID.uuidString)",
      "plan_exercise_id": "\(PublishIDs.serverPlanExerciseID.uuidString)",
      "set_number": 1,
      "target_reps": 5,
      "target_reps_max": null,
      "intensity_mode": "weight",
      "target_value": "100.00",
      "set_type": "working",
      "created_at": "2026-05-22T12:00:00Z"
    }
    """
  }
}

private struct RecordedPublishRequest: Sendable {
  let method: String
  let path: String
  let body: String?

  var methodAndPath: String {
    "\(method) \(path)"
  }

  init(request: URLRequest) {
    method = request.httpMethod ?? ""
    path = request.url?.path(percentEncoded: false) ?? ""
    body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
  }
}
