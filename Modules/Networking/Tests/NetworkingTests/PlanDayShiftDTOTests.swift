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

@Test func planDayShiftRequestAndResponseUseDateOnlyContract() throws {
  let request = ShiftPlanDayRequestDTO(shiftedToDate: utcDate(2026, 7, 10))
  let requestData = try MeetPRCodec.encoder.encode(request)
  let requestJSON = try #require(
    String(data: requestData, encoding: .utf8)
  )
  #expect(requestJSON == #"{"shifted_to_date":"2026-07-10"}"#)

  let responseJSON = """
    {
      "id": "70000000-0000-0000-0000-000000000001",
      "plan_day_id": "90000000-0000-0000-0000-000000000001",
      "shifted_to_date": "2026-07-10",
      "created_at": "2026-07-09T12:00:00Z"
    }
    """
  let response = try MeetPRCodec.decoder.decode(
    PlanDayShiftDTO.self,
    from: Data(responseJSON.utf8)
  )
  #expect(response.shiftedToDate == utcDate(2026, 7, 10))
  #expect(response.planDayID.uuidString == "90000000-0000-0000-0000-000000000001")
}

@Test func planDayShiftEndpointsUseFixedPathsAndMethods() async throws {
  let dayID = try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000001"))
  let log = PlanDayShiftRequestLog()
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    if request.httpMethod == "DELETE" {
      return APIResponse(data: Data(), statusCode: 204)
    }
    let response = """
      {
        "id": "70000000-0000-0000-0000-000000000001",
        "plan_day_id": "\(dayID.uuidString)",
        "shifted_to_date": "2026-07-10",
        "created_at": "2026-07-09T12:00:00Z"
      }
      """
    return APIResponse(data: Data(response.utf8), statusCode: 201)
  }

  _ = try await api.shiftPlanDay(
    id: dayID,
    to: utcDate(2026, 7, 10),
    accessToken: "token"
  )
  try await api.cancelPlanDayShift(id: dayID, accessToken: "token")

  let requests = await log.values
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /plans/days/\(dayID.uuidString)/shift",
      "DELETE /plans/days/\(dayID.uuidString)/shift",
    ])
  #expect(requests.first?.body == #"{"shifted_to_date":"2026-07-10"}"#)
}

private actor PlanDayShiftRequestLog {
  private(set) var values: [PlanDayShiftRecordedRequest] = []

  func record(_ request: URLRequest) {
    values.append(
      PlanDayShiftRecordedRequest(
        methodAndPath: "\(request.httpMethod ?? "") \(request.url?.path() ?? "")",
        body: request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
      )
    )
  }
}

private struct PlanDayShiftRecordedRequest: Sendable {
  let methodAndPath: String
  let body: String?
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date.distantPast
}
