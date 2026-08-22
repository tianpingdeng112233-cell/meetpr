import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func exerciseStatsDecodesOptionalSeriesAndUnknownTrend() throws {
  let json = #"""
    {
      "e1rm": {
        "squat": { "value": "180.125", "computed_at": "2026-08-20T10:00:00Z" },
        "bench": null,
        "deadlift": null
      },
      "e1rm_series": {
        "squat": {
          "points": [{ "date": "2026-08-20", "value": "180.125" }],
          "trend": "accelerating"
        },
        "bench": { "points": [], "trend": "flat" },
        "deadlift": { "points": [], "trend": "new" }
      },
      "one_rm": { "squat": "175.00", "bench": null, "deadlift": "215.00" },
      "ignored_future_field": true
    }
    """#

  let response = try MeetPRCodec.decoder.decode(
    CoachExerciseStatsResponseDTO.self,
    from: Data(json.utf8)
  )

  #expect(response.e1RM?.squat?.value == "180.125")
  #expect(response.e1RMSeries?.squat.points.first?.date == "2026-08-20")
  #expect(response.e1RMSeries?.squat.points.first?.value == "180.125")
  #expect(response.e1RMSeries?.squat.trend == .unknown("accelerating"))
  #expect(response.oneRM.deadlift == "215.00")
}

@Test func exerciseStatsDecodesLegacyResponseWithoutE1RMSeries() throws {
  let json = #"""
    {
      "one_rm": { "squat": null, "bench": null, "deadlift": null }
    }
    """#

  let response = try MeetPRCodec.decoder.decode(
    CoachExerciseStatsResponseDTO.self,
    from: Data(json.utf8)
  )

  #expect(response.e1RM == nil)
  #expect(response.e1RMSeries == nil)
}
