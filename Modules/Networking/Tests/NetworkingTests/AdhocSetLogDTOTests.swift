import CoreModels
import Foundation
import Testing

@testable import Networking

// Wire-format contract for spec 045 (backend spec 010): adhoc set logging
// bodies and the widened SetLogDTO rows returned under scope=all.

@Test func adhocSetLogRequestEncodesSnakeCaseWireKeys() throws {
  let dto = CreateAdhocSetLogRequestDTO(
    exerciseID: try #require(UUID(uuidString: "20000000-0000-4000-8000-000000000001")),
    loggedDate: "2026-07-04",
    setIndex: 0,
    weightKg: Decimal(string: "142.5")!,
    reps: 5,
    rpe: Decimal(string: "8.5")!,
    completed: true
  )

  let data = try MeetPRCodec.encoder.encode(dto)
  let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

  #expect(
    (object["exercise_id"] as? String)?.lowercased() == "20000000-0000-4000-8000-000000000001")
  #expect(object["logged_date"] as? String == "2026-07-04")
  #expect(object["set_index"] as? Int == 0)
  #expect(object["weight_kg"] as? String == "142.5")
  #expect(object["rpe"] as? String == "8.5")
  #expect(object["completed"] as? Bool == true)
  #expect(object["failed"] as? Bool == false)
  #expect(object["plan_exercise_id"] == nil)
}

@Test func setLogDTODecodesAdhocRowWithNullPlanExercise() throws {
  let json = """
    {
      "logs": [{
        "id": "11111111-0000-4000-8000-000000000001",
        "student_id": "10000000-0000-4000-8000-000000000005",
        "plan_exercise_id": null,
        "exercise_id": "20000000-0000-4000-8000-000000000001",
        "set_index": 0,
        "weight_kg": "142.50",
        "reps": 5,
        "rpe": "8.5",
        "completed": true,
        "failed": false,
        "adhoc": true,
        "logged_date": "2026-07-04",
        "logged_at": "2026-07-04T10:15:00.000Z"
      }]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    SetLogsResponseDTO.self, from: Data(json.utf8))
  let row = try #require(response.logs.first)

  #expect(row.planExerciseID == nil)
  #expect(row.exerciseID?.uuidString == "20000000-0000-4000-8000-000000000001")
  #expect(row.loggedDate == "2026-07-04")
  #expect(row.adhoc == true)
  #expect(row.weightKg == Decimal(string: "142.50"))
}

@Test func setLogDTODecodesLegacyPlanRowWithoutNewFields() throws {
  let json = """
    {
      "logs": [{
        "id": "11111111-0000-4000-8000-000000000002",
        "student_id": "10000000-0000-4000-8000-000000000003",
        "plan_exercise_id": "50000000-0000-4000-8000-000000000001",
        "set_index": 1,
        "weight_kg": "100.00",
        "reps": 5,
        "rpe": null,
        "completed": true,
        "failed": false,
        "logged_at": "2026-05-15T12:00:00.000Z"
      }]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    SetLogsResponseDTO.self, from: Data(json.utf8))
  let row = try #require(response.logs.first)

  #expect(row.planExerciseID?.uuidString == "50000000-0000-4000-8000-000000000001")
  #expect(row.exerciseID == nil)
  #expect(row.loggedDate == nil)
  #expect(row.adhoc == false)
  #expect(row.assumed == false)
}

/// Backend's imported-history rows add `assumed`; the DTO must not lose the
/// bit before StudentKit decides whether to backfill e1RM points (spec 053).
@Test func setLogDTODecodesAssumedImportedHistoryRow() throws {
  let json = """
    {
      "logs": [{
        "id": "11111111-0000-4000-8000-000000000003",
        "student_id": "10000000-0000-4000-8000-000000000003",
        "plan_exercise_id": "50000000-0000-4000-8000-000000000001",
        "exercise_id": "20000000-0000-4000-8000-000000000001",
        "set_index": 1,
        "weight_kg": "140.00",
        "reps": 5,
        "rpe": "8",
        "completed": true,
        "assumed": true,
        "logged_at": "2026-05-15T12:00:00.000Z"
      }]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    SetLogsResponseDTO.self, from: Data(json.utf8))
  #expect(response.logs.first?.assumed == true)
}
