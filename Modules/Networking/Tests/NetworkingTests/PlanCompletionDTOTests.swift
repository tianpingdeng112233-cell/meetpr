import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func planAndDayDecodeSequenceCompletionFields() throws {
  let data = Data(
    #"""
    {
      "id":"00000000-0000-4000-8000-000000000501",
      "coach_id":null,
      "trainee_id":"00000000-0000-4000-8000-000000000502",
      "name":"Cycle",
      "start_date":"2026-05-22",
      "end_date":"2026-06-18",
      "plan_weeks":4,
      "source":"coach",
      "status":"published",
      "published_at":"2026-05-23T12:00:00Z",
      "created_at":"2026-05-22T12:00:00Z",
      "updated_at":"2026-05-23T12:00:00Z"
    }
    """#
    .utf8
  )
  let plan = try MeetPRCodec.decoder.decode(PlanDTO.self, from: data)
  let publishedAt = try Date("2026-05-23T12:00:00Z", strategy: .iso8601)
  #expect(plan.publishedAt == publishedAt)

  let dayData = Data(
    #"""
    {
      "id":"00000000-0000-4000-8000-000000000505",
      "plan_id":"00000000-0000-4000-8000-000000000501",
      "day_of_week":2,
      "week_number":3,
      "sort_order":4,
      "completed_at":"2026-05-24T12:00:00Z",
      "completion_source":"auto",
      "exercises":[]
    }
    """#
    .utf8
  )
  let day = try MeetPRCodec.decoder.decode(PlanDayDTO.self, from: dayData)
  let completedAt = try Date("2026-05-24T12:00:00Z", strategy: .iso8601)
  #expect(day.completedAt == completedAt)
  #expect(day.completionSource == "auto")
}

@Test func completionResponseDecodesWireIdentity() throws {
  let data = Data(
    #"""
    {
      "id":"00000000-0000-4000-8000-000000000508",
      "plan_day_id":"00000000-0000-4000-8000-000000000505",
      "student_id":"00000000-0000-4000-8000-000000000502",
      "source":"manual",
      "completed_at":"2026-05-24T12:00:00Z"
    }
    """#
    .utf8
  )
  let completion = try MeetPRCodec.decoder.decode(PlanDayCompletionDTO.self, from: data)

  #expect(completion.source == "manual")
  #expect(completion.planDayID.uuidString.hasSuffix("0505"))
}
