import Foundation
import Testing

@testable import CoreModels

// Wire fixtures copied from the backend handlers' serialized shapes
// (handlers/evaluations.ts + evaluation-summary.ts).

@Test func evaluationPeriodDecodesBackendWireShape() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000601",
      "student_id": "00000000-0000-4000-8000-000000000602",
      "coach_id": "00000000-0000-4000-8000-000000000603",
      "bind_request_id": "00000000-0000-4000-8000-000000000604",
      "started_at": "2026-06-04T08:00:00.000Z",
      "expected_end_at": "2026-06-11T08:00:00.000Z",
      "completed_at": null,
      "completion_type": null,
      "in_progress": true,
      "overdue": false
    }
    """

  let period = try MeetPRCodec.decoder.decode(EvaluationPeriod.self, from: Data(json.utf8))

  #expect(period.inProgress)
  #expect(!period.overdue)
  #expect(period.completedAt == nil)
  #expect(period.completionType == nil)
  #expect(period.expectedEndAt.timeIntervalSince(period.startedAt) == 7 * 86_400)
}

@Test func evaluationPeriodRemainingAndProgressDeriveFromLocalNow() throws {
  let started = Date(timeIntervalSince1970: 1_780_000_000)
  let period = EvaluationPeriod(
    id: UUID(),
    studentId: UUID(),
    coachId: UUID(),
    bindRequestId: UUID(),
    startedAt: started,
    expectedEndAt: started.addingTimeInterval(7 * 86_400),
    inProgress: true,
    overdue: false
  )

  // 2 days 11 hours elapsed → 4 days 13 hours remaining.
  let now = started.addingTimeInterval((2 * 24 + 11) * 3_600)
  let remaining = try #require(period.remaining(now: now))
  #expect(remaining.days == 4)
  #expect(remaining.hours == 13)
  #expect(!period.isOverdue(now: now))
  #expect(period.overdueBy(now: now) == nil)
  let fraction = period.progressFraction(now: now)
  #expect(fraction > 0.35 && fraction < 0.36)

  // 2 days past the window → overdue, no remaining, progress clamps to 1.
  let overdueNow = started.addingTimeInterval(9 * 86_400)
  #expect(period.remaining(now: overdueNow) == nil)
  #expect(period.isOverdue(now: overdueNow))
  let overdueBy = try #require(period.overdueBy(now: overdueNow))
  #expect(overdueBy.days == 2)
  #expect(period.progressFraction(now: overdueNow) == 1)
}

@Test func completedEvaluationPeriodIsNeverOverdue() {
  let started = Date(timeIntervalSince1970: 1_780_000_000)
  let period = EvaluationPeriod(
    id: UUID(),
    studentId: UUID(),
    coachId: UUID(),
    bindRequestId: UUID(),
    startedAt: started,
    expectedEndAt: started.addingTimeInterval(7 * 86_400),
    completedAt: started.addingTimeInterval(3 * 86_400),
    completionType: "coach_completed",
    inProgress: false,
    overdue: false
  )
  let longAfter = started.addingTimeInterval(30 * 86_400)

  #expect(!period.isOverdue(now: longAfter))
  #expect(period.remaining(now: longAfter) == nil)
  #expect(period.overdueBy(now: longAfter) == nil)
}

@Test func evaluationSummaryDecodesBackendWireShape() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000701",
      "student_id": "00000000-0000-4000-8000-000000000702",
      "coach_id": "00000000-0000-4000-8000-000000000703",
      "evaluation_period_id": null,
      "overall_assessment": "底力扎实",
      "training_plan": "第一周期以技术为主",
      "words_to_student": null,
      "first_saved_at": "2026-06-10T08:00:00.000Z",
      "last_updated_at": "2026-06-11T09:30:00.000Z",
      "is_active": true
    }
    """

  let summary = try MeetPRCodec.decoder.decode(EvaluationSummary.self, from: Data(json.utf8))

  #expect(summary.evaluationPeriodId == nil)
  #expect(summary.wordsToStudent == nil)
  #expect(summary.isActive)
  #expect(summary.overallAssessment == "底力扎实")
}

@Test func evaluationSummaryExcerptTruncatesLinesAndLength() {
  #expect(EvaluationSummary.excerpt(of: "短句") == "短句")
  #expect(EvaluationSummary.excerpt(of: "一行\n二行\n三行") == "一行\n二行…")
  let long = String(repeating: "字", count: 120)
  let truncated = EvaluationSummary.excerpt(of: long)
  #expect(truncated.count == 81)
  #expect(truncated.hasSuffix("…"))
}

@Test func trainingPlanKindDefaultsToRegularWhenAbsent() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000801",
      "coach_id": null,
      "trainee_id": "00000000-0000-4000-8000-000000000802",
      "name": "Legacy plan",
      "start_date": "2026-05-22",
      "end_date": "2026-06-18",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-05-22T10:27:16.254Z",
      "updated_at": "2026-05-22T10:27:16.254Z"
    }
    """

  let plan = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: Data(json.utf8))
  #expect(plan.kind == .regular)
}

@Test func trainingPlanKindRoundTripsAdaptation() throws {
  let plan = TrainingPlan(
    id: UUID(),
    traineeID: UUID(),
    name: "适应周",
    startDate: Date(timeIntervalSince1970: 1_780_000_000),
    endDate: Date(timeIntervalSince1970: 1_780_600_000),
    planWeeks: 1,
    kind: .adaptation,
    source: .coach,
    status: .published,
    createdAt: Date(timeIntervalSince1970: 1_780_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_780_000_000)
  )

  let data = try MeetPRCodec.encoder.encode(plan)
  let decoded = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: data)
  #expect(decoded.kind == .adaptation)
}

@Test func studentPlanViewPlanKindDefaultsToRegular() throws {
  // Pre-033 cached projection without plan_kind.
  let json = """
    {
      "cycle_id": "00000000-0000-4000-8000-000000000901",
      "week_index": 1,
      "start_date": "2026-05-25T00:00:00.000Z",
      "days": []
    }
    """

  let view = try MeetPRCodec.decoder.decode(StudentPlanView.self, from: Data(json.utf8))
  #expect(view.planKind == .regular)
}
