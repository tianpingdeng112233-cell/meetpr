import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func coachStudentRosterDecodesDiscoveryFields() throws {
  let json = #"""
    {
      "students": [
        {
          "id": "05700000-0000-0000-0000-000000000001",
          "display_name": "王晨曦",
          "profile": {
            "user_id": "05700000-0000-0000-0000-000000000001",
            "display_name": "王晨曦",
            "created_at": "2026-07-18T09:00:00.000Z"
          },
          "status": "active",
          "competition_date": "2026-08-03",
          "recent_4w": [
            { "trained_days": 0, "planned_days": 3 },
            { "trained_days": 2, "planned_days": 3 },
            { "trained_days": 3, "planned_days": 3 },
            { "trained_days": 0, "planned_days": 0 }
          ]
        }
      ]
    }
    """#

  let response = try MeetPRCodec.decoder.decode(
    CoachStudentsResponseDTO.self,
    from: Data(json.utf8)
  )
  let student = try #require(response.students.first)

  #expect(student.competitionDate == "2026-08-03")
  #expect(
    student.recentFourWeeks == [
      CoachStudentRecentWeekDTO(trainedDays: 0, plannedDays: 3),
      CoachStudentRecentWeekDTO(trainedDays: 2, plannedDays: 3),
      CoachStudentRecentWeekDTO(trainedDays: 3, plannedDays: 3),
      CoachStudentRecentWeekDTO(trainedDays: 0, plannedDays: 0),
    ]
  )
}

@Test func coachStudentRosterDecodesLegacyResponseWithoutDiscoveryFields() throws {
  let json = #"""
    {
      "students": [
        {
          "id": "05700000-0000-0000-0000-000000000001",
          "display_name": "王晨曦",
          "profile": {
            "user_id": "05700000-0000-0000-0000-000000000001",
            "display_name": "王晨曦",
            "created_at": "2026-07-18T09:00:00.000Z"
          },
          "status": "active"
        }
      ]
    }
    """#

  let response = try MeetPRCodec.decoder.decode(
    CoachStudentsResponseDTO.self,
    from: Data(json.utf8)
  )
  let student = try #require(response.students.first)

  #expect(student.competitionDate == nil)
  #expect(student.recentFourWeeks == nil)
}
