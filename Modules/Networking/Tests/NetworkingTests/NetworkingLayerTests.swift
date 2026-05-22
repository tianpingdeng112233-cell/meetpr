import CoreModels
import Foundation
import Testing

@testable import Networking

// swiftlint:disable:next function_body_length
@Test func planTreeDTODecodesAndMapsToCoreModels() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "coach_id": "00000000-0000-4000-8000-000000000002",
      "trainee_id": "00000000-0000-4000-8000-000000000003",
      "name": "Cycle 1",
      "start_date": "2026-05-22",
      "end_date": "2026-06-18",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-05-22T12:00:00.000Z",
      "updated_at": "2026-05-22T13:00:00.000Z",
      "days": [
        {
          "id": "00000000-0000-4000-8000-000000000010",
          "plan_id": "00000000-0000-4000-8000-000000000001",
          "day_of_week": 1,
          "week_number": 1,
          "sort_order": 0,
          "exercises": [
            {
              "id": "00000000-0000-4000-8000-000000000020",
              "plan_day_id": "00000000-0000-4000-8000-000000000010",
              "exercise_id": "00000000-0000-4000-8000-000000000030",
              "is_main_lift": true,
              "sort_order": 0,
              "notes": null,
              "sets": [
                {
                  "id": "00000000-0000-4000-8000-000000000040",
                  "plan_exercise_id": "00000000-0000-4000-8000-000000000020",
                  "set_number": 1,
                  "target_reps": 5,
                  "target_reps_max": null,
                  "intensity_mode": "weight",
                  "target_value": "100.00",
                  "set_type": "working",
                  "created_at": "2026-05-22T12:00:00.000Z"
                }
              ]
            }
          ]
        }
      ]
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanWithChildrenDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.plan.name == "Cycle 1")
  #expect(domain.days.count == 1)
  #expect(domain.exercises.count == 1)
  #expect(domain.sets.count == 1)
  #expect(domain.sets[0].targetValue == Decimal(100))
}

@Test func setLogDTODecodesDecimalStringsAndMapsToDomain() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000101",
      "student_id": "00000000-0000-4000-8000-000000000102",
      "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
      "set_index": 1,
      "weight_kg": "100.00",
      "reps": 5,
      "rpe": "8.0",
      "completed": true,
      "logged_at": "2026-05-22T12:00:00.000Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.weightKg == Decimal(100))
  #expect(domain.rpe == Decimal(8))
  #expect(domain.completed)
}

@Test func feedbackDTODecodesDateOnlyAndISOTimestamps() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000201",
      "coach_id": "00000000-0000-4000-8000-000000000202",
      "student_id": "00000000-0000-4000-8000-000000000203",
      "day_date": "2026-05-22",
      "plan_exercise_id": null,
      "text": "Good pace.",
      "posted_at": "2026-05-22T12:00:00.000Z",
      "read_at": null
    }
    """

  let dto = try MeetPRCodec.decoder.decode(FeedbackDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()
  let postedAt = try isoDate("2026-05-22T12:00:00.000Z")

  #expect(WireFormatting.dateOnlyString(from: try #require(domain.dayDate)) == "2026-05-22")
  #expect(domain.postedAt == postedAt)
}

@Test func requestDTOsEncodeSnakeCaseDecimalStringsAndDateOnlyFields() throws {
  let planExerciseID = try uuid("00000000-0000-4000-8000-000000000301")
  let studentID = try uuid("00000000-0000-4000-8000-000000000302")
  let startDate = try isoDate("2026-05-22T15:30:00.000Z")
  let endDate = try isoDate("2026-06-18T08:00:00.000Z")

  let planRequest = CreatePlanRequestDTO(
    traineeID: studentID,
    name: "Cycle 1",
    startDate: startDate,
    endDate: endDate,
    planWeeks: 4,
    source: .coach
  )
  let setRequest = CreateSetLogRequestDTO(
    planExerciseID: planExerciseID,
    setIndex: 1,
    weightKg: Decimal(100),
    reps: 5,
    rpe: Decimal(8),
    completed: true
  )
  let feedbackRequest = CreateFeedbackRequestDTO(
    studentID: studentID,
    dayDate: startDate,
    text: "Nice work."
  )

  let planJSON = try jsonString(planRequest)
  let setJSON = try jsonString(setRequest)
  let feedbackJSON = try jsonString(feedbackRequest)

  #expect(planJSON.contains(#""trainee_id":"00000000-0000-4000-8000-000000000302""#))
  #expect(planJSON.contains(#""start_date":"2026-05-22""#))
  #expect(planJSON.contains(#""end_date":"2026-06-18""#))
  #expect(setJSON.contains(#""plan_exercise_id":"00000000-0000-4000-8000-000000000301""#))
  #expect(setJSON.contains(#""weight_kg":"100""#))
  #expect(setJSON.contains(#""rpe":"8""#))
  #expect(feedbackJSON.contains(#""student_id":"00000000-0000-4000-8000-000000000302""#))
  #expect(feedbackJSON.contains(#""day_date":"2026-05-22""#))
}

@Test func apiClientInjectsBearerTokenOnTypedEndpoint() async throws {
  let capture = TypedEndpointRequestCapture()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(data: Data(#"{"students":[]}"#.utf8), statusCode: 200)
  }

  _ = try await client.coachStudents(accessToken: "token-123")
  let request = try #require(await capture.request())

  #expect(request.url?.absoluteString == "https://api.test/coach/students")
  #expect(request.httpMethod == "GET")
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer token-123")
}

@Test
// swiftlint:disable:next function_body_length
func typedEndpointsUseWireContractPaths() async throws {
  let log = TypedEndpointRequestLog()
  let planID = try uuid("00000000-0000-4000-8000-000000000501")
  let studentID = try uuid("00000000-0000-4000-8000-000000000502")
  let feedbackID = try uuid("00000000-0000-4000-8000-000000000503")
  let planExerciseID = try uuid("00000000-0000-4000-8000-000000000504")
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return APIResponse(data: responseData(for: request), statusCode: statusCode(for: request))
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
  _ = try await client.publishPlan(id: planID, accessToken: "token")
  _ = try await client.studentPlans(
    studentID: studentID,
    status: [.published],
    accessToken: "token"
  )
  _ = try await client.plan(id: planID, accessToken: "token")
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
      "POST /plans/\(planID.uuidString)/publish",
      "GET /students/\(studentID.uuidString)/plans?status=published",
      "GET /plans/\(planID.uuidString)",
      "GET /coach/students",
      "POST /sets/log",
      "GET /students/\(studentID.uuidString)/sets?from=2026-05-22&to=2026-05-23",
      "POST /coach/feedback",
      "GET /students/\(studentID.uuidString)/feedback",
      "PATCH /feedback/\(feedbackID.uuidString)/read",
    ]
  )
}

@Test func apiClientPublishesAuthInvalidOn401() async throws {
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(#"{"error":"AUTH_INVALID_TOKEN"}"#.utf8), statusCode: 401)
  }
  var iterator = client.errorStream.makeAsyncIterator()

  do {
    _ = try await client.coachStudents(accessToken: "expired-token")
    Issue.record("Expected authInvalid to be thrown.")
  } catch let error as APIError {
    #expect(error == .authInvalid)
  }

  let streamedError = await iterator.next()
  #expect(streamedError == .authInvalid)
}

@Test func feedbackCacheDropsInvalidJSON() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "NetworkingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  let studentID = try uuid("00000000-0000-4000-8000-000000000401")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let fileURL = directory.appending(path: "student-\(studentID.uuidString)-feedback.json")
  try Data("not-json".utf8).write(to: fileURL)

  let cache = FeedbackCache(directory: directory)
  let value = await cache.loadFeedback(studentID: studentID)

  #expect(value == nil)
  #expect(!FileManager.default.fileExists(atPath: fileURL.path))
}

private func jsonString(_ value: some Encodable) throws -> String {
  let data = try MeetPRCodec.encoder.encode(value)
  return try #require(String(data: data, encoding: .utf8))
}

private func uuid(_ rawValue: String) throws -> UUID {
  try #require(UUID(uuidString: rawValue))
}

private func isoDate(_ rawValue: String) throws -> Date {
  if #available(iOS 15.0, macOS 12.0, *) {
    return try Date(rawValue, strategy: .iso8601)
  }

  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return try #require(formatter.date(from: rawValue))
}

private actor TypedEndpointRequestCapture {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }
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

private func responseData(for request: URLRequest) -> Data {
  switch (request.httpMethod, request.url?.path()) {
  case ("POST", "/plans"),
    ("POST", _?) where request.url?.path().hasSuffix("/publish") == true:
    Data(planJSON(id: "00000000-0000-4000-8000-000000000501").utf8)
  case ("GET", _?) where request.url?.path().hasSuffix("/plans") == true:
    Data(#"{"plans":[]}"#.utf8)
  case ("GET", _?) where request.url?.path() == "/plans/00000000-0000-4000-8000-000000000501":
    Data(planJSON(id: "00000000-0000-4000-8000-000000000501", includesChildren: true).utf8)
  case ("GET", "/coach/students"):
    Data(#"{"students":[]}"#.utf8)
  case ("POST", "/sets/log"):
    Data(
      #"{"id":"00000000-0000-4000-8000-000000000601","logged_at":"2026-05-22T12:00:00.000Z"}"#.utf8
    )
  case ("GET", _?) where request.url?.path().hasSuffix("/sets") == true:
    Data(#"{"logs":[]}"#.utf8)
  case ("POST", "/coach/feedback"):
    Data(feedbackJSON(id: "00000000-0000-4000-8000-000000000503").utf8)
  case ("GET", _?) where request.url?.path().hasSuffix("/feedback") == true:
    Data(#"{"items":[]}"#.utf8)
  default:
    Data("{}".utf8)
  }
}

private func statusCode(for request: URLRequest) -> Int {
  if request.httpMethod == "PATCH" {
    return 204
  }
  if request.httpMethod == "POST" && request.url?.path() != nil {
    return 201
  }
  return 200
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
    "created_at": "2026-05-22T12:00:00.000Z",
    "updated_at": "2026-05-22T12:00:00.000Z"\(includesChildren ? #","days":[]"# : "")
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
    "posted_at": "2026-05-22T12:00:00.000Z",
    "read_at": null
  }
  """
}
