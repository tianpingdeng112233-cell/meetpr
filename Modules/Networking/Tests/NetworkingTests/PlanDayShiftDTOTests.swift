import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func planDayDTODecodesShiftOverrideAndPassesItToDomain() throws {
  let json = """
    {
      "id": "90000000-0000-0000-0000-000000000001",
      "plan_id": "80000000-0000-0000-0000-000000000001",
      "day_of_week": 3,
      "week_number": 1,
      "sort_order": 0,
      "shifted_to_date": "2026-07-10",
      "exercises": []
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanDayDTO.self, from: Data(json.utf8))

  #expect(dto.shiftedToDate == utcDate(2026, 7, 10))
  #expect(dto.toDomain().shiftedToDate == utcDate(2026, 7, 10))
}

@Test func planDayDTODecodesNullAndMissingShiftAsNil() throws {
  let base = """
    "id": "90000000-0000-0000-0000-000000000001",
    "plan_id": "80000000-0000-0000-0000-000000000001",
    "day_of_week": 3,
    "week_number": 1,
    "sort_order": 0,
    "exercises": []
    """
  let nullDTO = try MeetPRCodec.decoder.decode(
    PlanDayDTO.self,
    from: Data("{\(base),\"shifted_to_date\":null}".utf8)
  )
  let missingDTO = try MeetPRCodec.decoder.decode(
    PlanDayDTO.self,
    from: Data("{\(base)}".utf8)
  )

  #expect(nullDTO.shiftedToDate == nil)
  #expect(missingDTO.shiftedToDate == nil)
}

@Test func planDTOParsesPlanLevelShiftMetadata() throws {
  let json = """
    {
      "id": "80000000-0000-0000-0000-000000000001",
      "coach_id": "80000000-0000-0000-0000-000000000002",
      "trainee_id": "80000000-0000-0000-0000-000000000003",
      "name": "比赛周期",
      "start_date": "2026-07-01",
      "end_date": "2026-07-28",
      "plan_weeks": 4,
      "kind": "regular",
      "source": "coach",
      "status": "published",
      "total_shift_days": 3,
      "latest_shift_created_at": "2026-07-11T12:00:00Z",
      "created_at": "2026-06-30T12:00:00Z",
      "updated_at": "2026-07-11T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(dto.totalShiftDays == 3)
  #expect(dto.latestShiftCreatedAt == isoDate("2026-07-11T12:00:00Z"))
  #expect(domain.totalShiftDays == 3)
  #expect(domain.latestShiftCreatedAt == dto.latestShiftCreatedAt)
}

@Test func planShiftResponseDecodesBatchAndAllShiftedDays() throws {
  let responseJSON = """
    {
      "batch_id": "70000000-0000-0000-0000-000000000001",
      "shifted_days": [
        {
          "day_id": "90000000-0000-0000-0000-000000000001",
          "shifted_to_date": "2026-07-12"
        },
        {
          "day_id": "90000000-0000-0000-0000-000000000002",
          "shifted_to_date": "2026-07-14"
        }
      ],
      "total_offset_days": 2
    }
    """
  let response = try MeetPRCodec.decoder.decode(
    PlanShiftDTO.self,
    from: Data(responseJSON.utf8)
  )

  #expect(response.shiftedDays.count == 2)
  #expect(response.shiftedDays[0].shiftedToDate == utcDate(2026, 7, 12))
  #expect(response.totalOffsetDays == 2)
}

@Test func planShiftEndpointsUsePlanPathAndNoRequestBody() async throws {
  let planID = try #require(UUID(uuidString: "80000000-0000-0000-0000-000000000001"))
  let log = PlanShiftRequestLog()
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    if request.httpMethod == "DELETE" {
      return APIResponse(data: Data(), statusCode: 204)
    }
    let response = """
      {
        "batch_id": "70000000-0000-0000-0000-000000000001",
        "shifted_days": [],
        "total_offset_days": 1
      }
      """
    return APIResponse(data: Data(response.utf8), statusCode: 201)
  }

  _ = try await api.shiftPlan(id: planID, accessToken: "token")
  try await api.cancelPlanShift(id: planID, accessToken: "token")

  let requests = await log.values
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /plans/\(planID.uuidString)/shift",
      "DELETE /plans/\(planID.uuidString)/shift",
    ])
  #expect(requests.allSatisfy { $0.body == nil })
}

private actor PlanShiftRequestLog {
  private(set) var values: [PlanShiftRecordedRequest] = []

  func record(_ request: URLRequest) {
    values.append(
      PlanShiftRecordedRequest(
        methodAndPath: "\(request.httpMethod ?? "") \(request.url?.path() ?? "")",
        body: request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
      )
    )
  }
}

private struct PlanShiftRecordedRequest: Sendable {
  let methodAndPath: String
  let body: String?
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}

private func isoDate(_ value: String) -> Date? {
  try? Date(value, strategy: .iso8601)
}
