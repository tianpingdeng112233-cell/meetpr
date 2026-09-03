import CoreModels
import Foundation
import Networking
import Testing

@Suite struct SetLogDTOTests {
  @Test func nilLoggedDateOmitsWireKey() throws {
    let request = makeRequest(loggedDate: nil)

    let object = try #require(
      JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(request))
        as? [String: Any]
    )

    #expect(object["logged_date"] == nil)
  }

  @Test func loggedDateUsesSnakeCaseWireKey() throws {
    let request = makeRequest(loggedDate: "2026-09-01")

    let object = try #require(
      JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(request))
        as? [String: Any]
    )

    #expect(object["logged_date"] as? String == "2026-09-01")
  }

  @Test func fetchedLogDecodesLoggedDateAndAnchorsBackfilledLogsOnTheirTrainingDay() throws {
    let json = """
      {
        "id": "00000000-0000-4000-8000-000000000101",
        "student_id": "00000000-0000-4000-8000-000000000102",
        "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
        "set_index": 1,
        "weight_kg": "100.00",
        "reps": 5,
        "completed": true,
        "logged_at": "2026-09-02T10:00:00Z",
        "logged_date": "2026-09-01"
      }
      """

    let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
    let domain = dto.toDomain()

    #expect(dto.loggedDate == "2026-09-01")
    #expect(domain.loggedDate == "2026-09-01")
    let calendar = Calendar.current
    #expect(calendar.component(.hour, from: domain.loggedAt) == 12)
    #expect(
      calendar.dateComponents([.year, .month, .day], from: domain.loggedAt)
        == DateComponents(year: 2026, month: 9, day: 1))
  }

  @Test func fetchedLogWithoutLoggedDateKeepsServerTimestamp() throws {
    let json = """
      {
        "id": "00000000-0000-4000-8000-000000000101",
        "student_id": "00000000-0000-4000-8000-000000000102",
        "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
        "set_index": 1,
        "weight_kg": "100.00",
        "reps": 5,
        "completed": true,
        "logged_at": "2026-09-02T10:00:00Z"
      }
      """

    let domain = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8)).toDomain()

    #expect(domain.loggedDate == nil)
    #expect(domain.loggedAt == Date(timeIntervalSince1970: 1_788_343_200))
  }

  @Test func fetchedLogOnItsOwnGymDayKeepsServerTimestamp() throws {
    // 03:30 UTC on 9/2 is still gym-day 9/1 (04:00 cutoff): a live set, not a backfill.
    let json = """
      {
        "id": "00000000-0000-4000-8000-000000000101",
        "student_id": "00000000-0000-4000-8000-000000000102",
        "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
        "set_index": 1,
        "weight_kg": "100.00",
        "reps": 5,
        "completed": true,
        "logged_at": "2026-09-02T03:30:00Z",
        "logged_date": "2026-09-01"
      }
      """

    let domain = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
      .toDomain(calendar: utcCalendar)

    #expect(domain.loggedDate == "2026-09-01")
    #expect(domain.loggedAt == Date(timeIntervalSince1970: 1_788_319_800))
  }

  @Test func backfilledLogOnADSTTransitionDayStillAnchorsAtLocalNoon() throws {
    // Europe/London springs forward on 2026-03-29; "start of day + 12h" would give 13:00.
    var london = Calendar(identifier: .gregorian)
    london.timeZone = TimeZone(identifier: "Europe/London") ?? .current
    let json = """
      {
        "id": "00000000-0000-4000-8000-000000000101",
        "student_id": "00000000-0000-4000-8000-000000000102",
        "plan_exercise_id": "00000000-0000-4000-8000-000000000103",
        "set_index": 1,
        "weight_kg": "100.00",
        "reps": 5,
        "completed": true,
        "logged_at": "2026-04-02T10:00:00Z",
        "logged_date": "2026-03-29"
      }
      """

    let domain = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
      .toDomain(calendar: london)

    #expect(london.component(.hour, from: domain.loggedAt) == 12)
    #expect(london.component(.day, from: domain.loggedAt) == 29)
  }

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }

  private func makeRequest(loggedDate: String?) -> CreateSetLogRequestDTO {
    CreateSetLogRequestDTO(
      planExerciseID: UUID(),
      setIndex: 0,
      weightKg: 140,
      reps: 5,
      rpe: 8,
      completed: true,
      loggedDate: loggedDate
    )
  }
}
