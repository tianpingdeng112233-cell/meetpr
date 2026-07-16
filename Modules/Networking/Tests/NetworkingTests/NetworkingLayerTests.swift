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
      "created_at": "2026-05-22T12:00:00.254Z",
      "updated_at": "2026-05-22T13:00:00Z",
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
                  "rest_seconds": 210,
                  "created_at": "2026-05-22T12:00:00Z"
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
  #expect(domain.sets[0].restSeconds == 210)
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
      "logged_at": "2026-05-22T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.weightKg == Decimal(100))
  #expect(domain.rpe == Decimal(8))
  #expect(domain.completed)
  #expect(!domain.failed)
  #expect(!dto.assumed)
  #expect(!domain.assumed)
}

@Test func setLogDTODecodesFailedTrueAndMapsToDomain() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000101",
      "student_id": "00000000-0000-4000-8000-000000000102",
      "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
      "set_index": 1,
      "weight_kg": "100.00",
      "reps": 3,
      "rpe": "9.0",
      "completed": true,
      "failed": true,
      "logged_at": "2026-05-22T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(dto.failed)
  #expect(domain.completed)
  #expect(domain.failed)
}

@Test func setLogDTOPreservesAssumedTrueAndMapsToDomain() throws {
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
      "failed": false,
      "assumed": true,
      "logged_at": "2026-05-22T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  let encoded = try MeetPRCodec.encoder.encode(dto)
  let encodedJSON = try #require(String(data: encoded, encoding: .utf8))
  let domain = dto.toDomain()

  #expect(dto.assumed)
  #expect(domain.assumed)
  #expect(encodedJSON.contains(#""assumed":true"#))
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
      "posted_at": "2026-05-22T12:00:00Z",
      "read_at": null
    }
    """

  let dto = try MeetPRCodec.decoder.decode(FeedbackDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()
  let postedAt = try isoDate("2026-05-22T12:00:00Z")

  #expect(WireFormatting.dateOnlyString(from: try #require(domain.dayDate)) == "2026-05-22")
  #expect(domain.postedAt == postedAt)
}

@Test func requestDTOsEncodeSnakeCaseDecimalStringsAndDateOnlyFields() throws {
  let planExerciseID = try uuid("00000000-0000-4000-8000-000000000301")
  let studentID = try uuid("00000000-0000-4000-8000-000000000302")
  let startDate = try isoDate("2026-05-22T15:30:00Z")
  let endDate = try isoDate("2026-06-18T08:00:00Z")

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
  let planSetRequest = CreatePlanSetRequestDTO(
    setNumber: 1,
    targetReps: 5,
    targetRepsMax: 8,
    intensityMode: .weight,
    targetValue: Decimal(100.125),
    setType: .working,
    restSeconds: 195
  )

  let planJSON = try jsonString(planRequest)
  let setJSON = try jsonString(setRequest)
  let feedbackJSON = try jsonString(feedbackRequest)
  let planSetJSON = try jsonString(planSetRequest)

  #expect(planJSON.contains(#""trainee_id":"00000000-0000-4000-8000-000000000302""#))
  #expect(planJSON.contains(#""start_date":"2026-05-22""#))
  #expect(planJSON.contains(#""end_date":"2026-06-18""#))
  #expect(setJSON.contains(#""plan_exercise_id":"00000000-0000-4000-8000-000000000301""#))
  #expect(setJSON.contains(#""weight_kg":"100""#))
  #expect(setJSON.contains(#""rpe":"8""#))
  #expect(setJSON.contains(#""failed":false"#))
  #expect(feedbackJSON.contains(#""student_id":"00000000-0000-4000-8000-000000000302""#))
  #expect(feedbackJSON.contains(#""day_date":"2026-05-22""#))
  #expect(planSetJSON.contains(#""target_value":"100.13""#))
  #expect(planSetJSON.contains(#""target_reps_max":8"#))
  #expect(planSetJSON.contains(#""rest_seconds":195"#))
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

@Test func apiClientRefreshesAndRetriesAuthenticatedRequestAfter401() async throws {
  let transport = UnauthorizedRetryTransport()
  let recovery = UnauthorizedRecoverySpy()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await transport.response(for: request)
  }
  client.bindUnauthorizedRecovery { rejectedAccessToken in
    await recovery.recover(rejectedAccessToken)
  }

  let response = try await client.coachStudents(accessToken: "expired-token")
  let authorizationHeaders = await transport.authorizationHeaders()

  #expect(response.students.isEmpty)
  #expect(authorizationHeaders == ["Bearer expired-token", "Bearer refreshed-token"])
  #expect(await recovery.rejectedTokens() == ["expired-token"])
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

private actor UnauthorizedRetryTransport {
  private var headers: [String] = []

  func response(for request: URLRequest) -> APIResponse {
    let authorization = request.value(forHTTPHeaderField: "authorization") ?? ""
    headers.append(authorization)
    if authorization == "Bearer expired-token" {
      return APIResponse(data: Data(), statusCode: 401)
    }
    return APIResponse(data: Data(#"{"students":[]}"#.utf8), statusCode: 200)
  }

  func authorizationHeaders() -> [String] {
    headers
  }
}

private actor UnauthorizedRecoverySpy {
  private var tokens: [String] = []

  func recover(_ rejectedAccessToken: String) -> String {
    tokens.append(rejectedAccessToken)
    return "refreshed-token"
  }

  func rejectedTokens() -> [String] {
    tokens
  }
}
