import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rosterLoadsStudentsAndComputesAttentionBadge() async {
  let plan = CoachStudentFeatureFixtures.plan()
  let recentLogDate = CoachStudentFeatureFixtures.startDate.addingTimeInterval(86_400 + 3_600)
  let now = CoachStudentFeatureFixtures.startDate.addingTimeInterval(2 * 86_400)
  let first = CoachStudentFeatureFixtures.summary()
  let second = CoachStudentFeatureFixtures.summary(
    id: CoachStudentFeatureFixtures.secondStudentID,
    name: "已反馈学员"
  )
  let viewModel = StudentRosterViewModel(
    students: StubCoachPlanRepository(students: [first, second]),
    plans: StubStudentPlanRepository(
      plans: [
        first.id: plan,
        second.id: plan,
      ]
    ),
    trainingLogs: StubTrainingLogRepository(
      logs: [
        CoachStudentFeatureFixtures.log(studentID: first.id, loggedAt: recentLogDate),
        CoachStudentFeatureFixtures.log(studentID: second.id, loggedAt: recentLogDate),
      ]
    ),
    feedback: StubFeedbackRepository(
      feedback: [
        CoachStudentFeatureFixtures.feedback(
          studentID: second.id,
          postedAt: recentLogDate.addingTimeInterval(600)
        )
      ]
    ),
    now: { now }
  )

  await viewModel.refresh()

  #expect(viewModel.rows.count == 2)
  #expect(viewModel.pendingAttentionCount == 1)
  #expect(viewModel.rows[0].plannedTrainingDays == 1)
  #expect(viewModel.rows[0].completedTrainingDays == 1)
  #expect(viewModel.rows[0].needsAttention)
  #expect(!viewModel.rows[1].needsAttention)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rosterMovesToFailedStateWhenStudentsCannotLoad() async {
  let viewModel = StudentRosterViewModel(
    students: StubCoachPlanRepository(
      students: [],
      error: CoachFeatureTestError()
    ),
    plans: StubStudentPlanRepository(plans: [:]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository()
  )

  await viewModel.refresh()

  #expect(viewModel.rows.isEmpty)
  guard case .failed = viewModel.state else {
    Issue.record("Expected failed state")
    return
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func markStudentActiveDropsInEvaluationBadgeInPlace() async {
  let inEvaluation = CoachStudentFeatureFixtures.summary(
    status: .inEvaluation(remainingDays: 4, remainingHours: 13))
  let other = CoachStudentFeatureFixtures.summary(
    id: CoachStudentFeatureFixtures.secondStudentID,
    name: "在册学员"
  )
  let viewModel = StudentRosterViewModel(
    students: StubCoachPlanRepository(students: [inEvaluation, other]),
    plans: StubStudentPlanRepository(plans: [:]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository(feedback: []),
    now: { CoachStudentFeatureFixtures.startDate }
  )
  await viewModel.refresh()
  #expect(viewModel.rows[0].student.status != .active)

  viewModel.markStudentActive(inEvaluation.id)

  // Only the completed student's row flips; the rest stay untouched.
  #expect(viewModel.rows[0].student.status == .active)
  #expect(viewModel.rows[0].student.displayName == inEvaluation.displayName)
  #expect(viewModel.rows[1].student == other)
}
