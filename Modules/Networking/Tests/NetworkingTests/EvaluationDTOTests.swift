import CoreModels
import Foundation
import Testing

@testable import Networking

// Wire fixtures copied from backend handlers (evaluations.ts /
// evaluation-summary.ts / coach-bind-requests.ts serialized shapes).

@Test func evaluationPeriodDTODecodesAndMapsToDomain() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000601",
      "student_id": "00000000-0000-4000-8000-000000000602",
      "coach_id": "00000000-0000-4000-8000-000000000603",
      "bind_request_id": "00000000-0000-4000-8000-000000000604",
      "started_at": "2026-06-04T08:00:00.000Z",
      "expected_end_at": "2026-06-11T08:00:00.000Z",
      "completed_at": "2026-06-09T10:00:00.000Z",
      "completion_type": "coach_completed",
      "in_progress": false,
      "overdue": false
    }
    """

  let dto = try MeetPRCodec.decoder.decode(EvaluationPeriodDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.completionType == "coach_completed")
  #expect(domain.completedAt != nil)
  #expect(!domain.inProgress)
}

@Test func evaluationSummaryPutBodyOmitsBlankWords() throws {
  let body = PutEvaluationSummaryRequestDTO(
    overallAssessment: "底力扎实",
    trainingPlan: "技术周期",
    wordsToStudent: nil,
    notifyStudent: true
  )

  let data = try MeetPRCodec.encoder.encode(body)
  let object = try #require(
    try JSONSerialization.jsonObject(with: data) as? [String: Any])

  #expect(object["words_to_student"] == nil)
  #expect(object["notify_student"] as? Bool == true)
  #expect(object["overall_assessment"] as? String == "底力扎实")
}

@Test func acceptBindRequestBodyOmitsSkipReasonWhenNil() throws {
  let evaluate = AcceptBindRequestRequestDTO(skipEvaluation: false, skipReason: nil)
  let evaluateObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(evaluate))
      as? [String: Any])
  // zod superRefine rejects skip_reason unless skip_evaluation is true —
  // the key must be absent, not null.
  #expect(evaluateObject["skip_reason"] == nil)
  #expect(evaluateObject["skip_evaluation"] as? Bool == false)

  let skip = AcceptBindRequestRequestDTO(skipEvaluation: true, skipReason: "老学员")
  let skipObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(skip)) as? [String: Any])
  #expect(skipObject["skip_reason"] as? String == "老学员")
  #expect(skipObject["skip_evaluation"] as? Bool == true)
}

@Test func rejectBodyEncodesStrictEmptyObject() throws {
  let data = try MeetPRCodec.encoder.encode(EmptyObjectBodyDTO())
  #expect(String(data: data, encoding: .utf8) == "{}")
}

@Test func acceptResponseDecodesEvaluationPeriod() throws {
  let withPeriod = """
    {
      "bind_request": {
        "id": "00000000-0000-4000-8000-000000000611",
        "student_id": "00000000-0000-4000-8000-000000000612",
        "coach_id": "00000000-0000-4000-8000-000000000613",
        "coach_display_name": null,
        "invite_code_id": null,
        "status": "accepted",
        "submitted_at": "2026-06-10T08:00:00.000Z",
        "responded_at": "2026-06-11T08:00:00.000Z",
        "expired_at": "2026-06-17T08:00:00.000Z",
        "skip_evaluation": false,
        "skip_reason": null
      },
      "evaluation_period": {
        "id": "00000000-0000-4000-8000-000000000614",
        "student_id": "00000000-0000-4000-8000-000000000612",
        "coach_id": "00000000-0000-4000-8000-000000000613",
        "bind_request_id": "00000000-0000-4000-8000-000000000611",
        "started_at": "2026-06-11T08:00:00.000Z",
        "expected_end_at": "2026-06-18T08:00:00.000Z",
        "completed_at": null,
        "completion_type": null,
        "in_progress": true,
        "overdue": false
      }
    }
    """
  let accepted = try MeetPRCodec.decoder.decode(
    AcceptBindRequestResponseDTO.self, from: Data(withPeriod.utf8))
  #expect(accepted.bindRequest.status == .accepted)
  #expect(accepted.evaluationPeriod?.inProgress == true)
}

@Test func acceptResponseDecodesNullEvaluationPeriodOnSkip() throws {
  let skipped = """
    {
      "bind_request": {
        "id": "00000000-0000-4000-8000-000000000611",
        "student_id": "00000000-0000-4000-8000-000000000612",
        "coach_id": "00000000-0000-4000-8000-000000000613",
        "coach_display_name": null,
        "invite_code_id": null,
        "status": "accepted",
        "submitted_at": "2026-06-10T08:00:00.000Z",
        "responded_at": "2026-06-11T08:00:00.000Z",
        "expired_at": "2026-06-17T08:00:00.000Z",
        "skip_evaluation": true,
        "skip_reason": "老学员"
      },
      "evaluation_period": null
    }
    """
  let skippedResponse = try MeetPRCodec.decoder.decode(
    AcceptBindRequestResponseDTO.self, from: Data(skipped.utf8))
  #expect(skippedResponse.evaluationPeriod == nil)
  #expect(skippedResponse.bindRequest.skipReason == "老学员")
}

@Test func coachBindRequestItemDecodesNineItemSummary() throws {
  let json = """
    {
      "bind_requests": [
        {
          "id": "00000000-0000-4000-8000-000000000621",
          "student_id": "00000000-0000-4000-8000-000000000622",
          "display_name": "张三",
          "submitted_at": "2026-06-11T06:00:00.000Z",
          "expired_at": "2026-06-18T06:00:00.000Z",
          "onboarding": {
            "completed": true,
            "gender": "male",
            "birth_date": "2001-03-15",
            "weight_kg": "83.00",
            "training_years": 3,
            "squat_1rm_kg": "180.00",
            "bench_1rm_kg": "120.00",
            "deadlift_1rm_kg": "220.00",
            "muscle_groups_to_strengthen": ["quad", "hamstring", "shoulder"],
            "gym_tier": "commercial",
            "is_competing": true,
            "competition_date": "2026-07-25",
            "note_to_coach": "想突破 200kg 深蹲",
            "upload_count": 4
          }
        }
      ]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    CoachBindRequestsResponseDTO.self, from: Data(json.utf8))
  let item = try #require(response.bindRequests.first)

  #expect(item.displayName == "张三")
  #expect(item.onboarding.completed)
  #expect(item.onboarding.squat1RMKg == 180)
  #expect(item.onboarding.weightKg == 83)
  #expect(item.onboarding.muscleGroupsToStrengthen == [.quad, .hamstring, .shoulder])
  #expect(item.onboarding.gymTier == .commercial)
  #expect(item.onboarding.uploadCount == 4)
}

@Test func coachBindRequestItemDecodesDegradedNullOnboarding() throws {
  // Onboarding row missing → completed false, all nulls, upload_count 0.
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000631",
      "student_id": "00000000-0000-4000-8000-000000000632",
      "display_name": "李四",
      "submitted_at": "2026-06-11T06:00:00.000Z",
      "expired_at": "2026-06-18T06:00:00.000Z",
      "onboarding": {
        "completed": false,
        "gender": null,
        "birth_date": null,
        "weight_kg": null,
        "training_years": null,
        "squat_1rm_kg": null,
        "bench_1rm_kg": null,
        "deadlift_1rm_kg": null,
        "muscle_groups_to_strengthen": null,
        "gym_tier": null,
        "is_competing": null,
        "competition_date": null,
        "note_to_coach": null,
        "upload_count": 0
      }
    }
    """

  let item = try MeetPRCodec.decoder.decode(
    CoachBindRequestItemDTO.self, from: Data(json.utf8))

  #expect(!item.onboarding.completed)
  #expect(item.onboarding.squat1RMKg == nil)
  #expect(item.onboarding.muscleGroupsToStrengthen.isEmpty)
  #expect(item.onboarding.uploadCount == 0)
}

@Test func createPlanRequestAlwaysCarriesExplicitKind() throws {
  let regular = CreatePlanRequestDTO(
    traineeID: UUID(),
    name: "正式计划",
    startDate: "2026-06-15",
    endDate: "2026-07-12",
    planWeeks: 4,
    source: .coach
  )
  let regularObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(regular))
      as? [String: Any])
  // Explicit even for the default (spec 033 D9).
  #expect(regularObject["kind"] as? String == "regular")

  let adaptation = CreatePlanRequestDTO(
    traineeID: UUID(),
    name: "适应周",
    startDate: "2026-06-15",
    endDate: "2026-06-21",
    planWeeks: 1,
    kind: .adaptation,
    source: .coach
  )
  let adaptationObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(adaptation))
      as? [String: Any])
  #expect(adaptationObject["kind"] as? String == "adaptation")
}

@Test func planDTODecodesKindWithRegularDefault() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000641",
      "coach_id": null,
      "trainee_id": "00000000-0000-4000-8000-000000000642",
      "name": "适应周",
      "start_date": "2026-06-15",
      "end_date": "2026-06-21",
      "plan_weeks": 1,
      "kind": "adaptation",
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-06-11T08:00:00.000Z",
      "updated_at": "2026-06-11T08:00:00.000Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanDTO.self, from: Data(json.utf8))
  #expect(dto.kind == .adaptation)
  #expect(dto.toDomain().kind == .adaptation)
}
