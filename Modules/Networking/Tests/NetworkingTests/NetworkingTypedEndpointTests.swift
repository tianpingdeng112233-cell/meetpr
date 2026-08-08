import CoreModels
import Foundation
import Testing

@testable import Networking

@Test
// swiftlint:disable:next function_body_length
func typedEndpointsUseWireContractPaths() async throws {
  let log = TypedEndpointRequestLog()
  let stub = TypedEndpointResponseStub()
  let planID = try uuid("00000000-0000-4000-8000-000000000501")
  let dayID = try uuid("00000000-0000-4000-8000-000000000505")
  let planTreeExerciseID = try uuid("00000000-0000-4000-8000-000000000506")
  let studentID = try uuid("00000000-0000-4000-8000-000000000502")
  let feedbackID = try uuid("00000000-0000-4000-8000-000000000503")
  let planExerciseID = try uuid("00000000-0000-4000-8000-000000000504")
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return stub.response(for: request)
  }

  _ = try await client.createPlan(
    CreatePlanRequestDTO(
      traineeID: studentID,
      name: "Cycle 1",
      startDate: "2026-05-22",
      endDate: "2026-06-18",
      planWeeks: 4,
      source: .coach
    ),
    accessToken: "token"
  )
  _ = try await client.createPlanDay(
    planID: planID,
    CreatePlanDayRequestDTO(dayOfWeek: 1, weekNumber: 1, sortOrder: 0),
    accessToken: "token"
  )
  _ = try await client.createPlanExercise(
    dayID: dayID,
    CreatePlanExerciseRequestDTO(
      exerciseID: planTreeExerciseID,
      isMainLift: true,
      sortOrder: 0
    ),
    accessToken: "token"
  )
  _ = try await client.createPlanSet(
    planExerciseID: planExerciseID,
    CreatePlanSetRequestDTO(
      setNumber: 1,
      targetReps: 5,
      intensityMode: .weight,
      targetValue: Decimal(100),
      setType: .working
    ),
    accessToken: "token"
  )
  _ = try await client.publishPlan(id: planID, accessToken: "token")
  _ = try await client.studentPlans(
    studentID: studentID,
    status: [.published],
    accessToken: "token"
  )
  _ = try await client.plan(id: planID, accessToken: "token")
  _ = try await client.completePlanDay(id: dayID, accessToken: "token")
  try await client.undoPlanDayCompletion(id: dayID, accessToken: "token")
  _ = try await client.coachStudents(accessToken: "token")
  _ = try await client.logSet(
    CreateSetLogRequestDTO(
      planExerciseID: planExerciseID,
      setIndex: 1,
      weightKg: Decimal(100),
      reps: 5,
      completed: true
    ),
    accessToken: "token"
  )
  _ = try await client.studentSetLogs(
    studentID: studentID,
    from: "2026-05-22",
    endDate: "2026-05-23",
    accessToken: "token"
  )
  _ = try await client.createFeedback(
    CreateFeedbackRequestDTO(studentID: studentID, dayDate: "2026-05-22", text: "Nice."),
    accessToken: "token"
  )
  _ = try await client.studentFeedback(studentID: studentID, accessToken: "token")
  try await client.markFeedbackRead(id: feedbackID, accessToken: "token")

  let requests = await log.requests()
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /plans",
      "POST /plans/\(planID.uuidString)/days",
      "POST /plans/days/\(dayID.uuidString)/exercises",
      "POST /plans/exercises/\(planExerciseID.uuidString)/sets",
      "POST /plans/\(planID.uuidString)/publish",
      "GET /students/\(studentID.uuidString)/plans?status=published",
      "GET /plans/\(planID.uuidString)",
      "POST /plans/days/\(dayID.uuidString)/complete",
      "DELETE /plans/days/\(dayID.uuidString)/complete",
      "GET /coach/students",
      "POST /sets/log",
      "GET /students/\(studentID.uuidString)/sets?from=2026-05-22&to=2026-05-23&scope=plan",
      "POST /coach/feedback",
      "GET /students/\(studentID.uuidString)/feedback",
      "PATCH /feedback/\(feedbackID.uuidString)/read",
    ]
  )
}

private func uuid(_ rawValue: String) throws -> UUID {
  try #require(UUID(uuidString: rawValue))
}

private actor TypedEndpointRequestLog {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [RecordedRequest] {
    capturedRequests.map(RecordedRequest.init(request:))
  }
}

private struct RecordedRequest: Sendable {
  let methodAndPath: String

  init(request: URLRequest) {
    let method = request.httpMethod ?? ""
    let url = request.url
    var path = url?.path(percentEncoded: false) ?? ""
    if let query = url?.query(percentEncoded: false), !query.isEmpty {
      path += "?\(query)"
    }
    methodAndPath = "\(method) \(path)"
  }
}

private struct TypedEndpointResponseStub: Sendable {
  func response(for request: URLRequest) -> APIResponse {
    APIResponse(data: data(for: request), statusCode: statusCode(for: request))
  }

  private func data(for request: URLRequest) -> Data {
    let method = request.httpMethod ?? ""
    let path = request.url?.path() ?? ""

    if method == "GET" {
      return getData(for: path)
    }
    if method == "POST" {
      return postData(for: path)
    }
    return Data("{}".utf8)
  }

  private func getData(for path: String) -> Data {
    if path == "/plans/00000000-0000-4000-8000-000000000501" {
      return Data(planJSON(id: "00000000-0000-4000-8000-000000000501", includesChildren: true).utf8)
    }
    if path == "/coach/students" {
      return Data(#"{"students":[]}"#.utf8)
    }
    if path.hasSuffix("/sets") {
      return Data(#"{"logs":[]}"#.utf8)
    }
    if path.hasSuffix("/feedback") {
      return Data(#"{"items":[]}"#.utf8)
    }
    if path.hasSuffix("/plans") {
      return Data(#"{"plans":[]}"#.utf8)
    }
    return Data("{}".utf8)
  }

  private func postData(for path: String) -> Data {
    if path.hasSuffix("/complete") {
      return Data(
        #"""
        {
          "id":"00000000-0000-4000-8000-000000000508",
          "plan_day_id":"00000000-0000-4000-8000-000000000505",
          "student_id":"00000000-0000-4000-8000-000000000502",
          "source":"manual",
          "completed_at":"2026-05-22T12:00:00Z"
        }
        """#
        .utf8
      )
    }
    if path == "/plans" || path.hasSuffix("/publish") {
      return Data(planJSON(id: "00000000-0000-4000-8000-000000000501").utf8)
    }
    if path.hasSuffix("/days") {
      return Data(planDayJSON(id: "00000000-0000-4000-8000-000000000505").utf8)
    }
    if path.hasSuffix("/exercises") {
      return Data(planExerciseJSON(id: "00000000-0000-4000-8000-000000000504").utf8)
    }
    if path.hasSuffix("/sets") {
      return Data(planSetJSON(id: "00000000-0000-4000-8000-000000000507").utf8)
    }
    if path == "/sets/log" {
      return Data(
        #"{"id":"00000000-0000-4000-8000-000000000601","logged_at":"2026-05-22T12:00:00Z"}"#.utf8
      )
    }
    if path == "/coach/feedback" {
      return Data(feedbackJSON(id: "00000000-0000-4000-8000-000000000503").utf8)
    }
    return Data("{}".utf8)
  }

  private func statusCode(for request: URLRequest) -> Int {
    if request.httpMethod == "PATCH" {
      return 204
    }
    return request.httpMethod == "POST" ? 201 : 200
  }
}

private func planJSON(id: String, includesChildren: Bool = false) -> String {
  """
  {
    "id": "\(id)",
    "coach_id": "00000000-0000-4000-8000-000000000511",
    "trainee_id": "00000000-0000-4000-8000-000000000502",
    "name": "Cycle 1",
    "start_date": "2026-05-22",
    "end_date": "2026-06-18",
    "plan_weeks": 4,
    "source": "coach",
    "source_template_id": null,
    "status": "published",
    "created_at": "2026-05-22T12:00:00Z",
    "updated_at": "2026-05-22T12:00:00Z"\(includesChildren ? #","days":[]"# : "")
  }
  """
}

private func planDayJSON(id: String) -> String {
  """
  {
    "id": "\(id)",
    "plan_id": "00000000-0000-4000-8000-000000000501",
    "day_of_week": 1,
    "week_number": 1,
    "sort_order": 0,
    "exercises": []
  }
  """
}

private func planExerciseJSON(id: String) -> String {
  """
  {
    "id": "\(id)",
    "plan_day_id": "00000000-0000-4000-8000-000000000505",
    "exercise_id": "00000000-0000-4000-8000-000000000506",
    "is_main_lift": true,
    "sort_order": 0,
    "notes": null,
    "sets": []
  }
  """
}

private func planSetJSON(id: String) -> String {
  """
  {
    "id": "\(id)",
    "plan_exercise_id": "00000000-0000-4000-8000-000000000504",
    "set_number": 1,
    "target_reps": 5,
    "target_reps_max": null,
    "intensity_mode": "weight",
    "target_value": "100.00",
    "set_type": "working",
    "rest_seconds": 180,
    "created_at": "2026-05-22T12:00:00Z"
  }
  """
}

private func feedbackJSON(id: String) -> String {
  """
  {
    "id": "\(id)",
    "coach_id": "00000000-0000-4000-8000-000000000511",
    "student_id": "00000000-0000-4000-8000-000000000502",
    "day_date": "2026-05-22",
    "plan_exercise_id": null,
    "text": "Nice.",
    "posted_at": "2026-05-22T12:00:00Z",
    "read_at": null
  }
  """
}
