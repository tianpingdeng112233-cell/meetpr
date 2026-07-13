import Testing

@testable import Analytics

@Test func analyticsEventNamesUseBackendRegistryValues() {
  let expected: [String: Set<String>] = [
    "app_open": ["cold"],
    "screen_view": ["screen"],
    "workout_log_start": ["plan_id", "source"],
    "set_logged": ["exercise_id", "set_index", "has_video", "outcome"],
    "workout_log_save": ["n_sets", "duration_ms"],
    "onboarding_step": ["step_index", "step_name"],
    "onboarding_complete": ["n_steps_filled", "used_draft_resume"],
    "bind_coach_action": ["stage"],
    "plan_viewed": ["plan_id"],
    "progress_viewed": ["tab"],
    "coach_open_student": ["student_id"],
    "coach_feedback_sent": ["student_id", "kind"],
    "coach_plan_assigned": ["student_id"],
    "coach_intake_action": ["stage", "student_id"],
    "eval_summary_action": ["stage", "student_id"],
    "validation_error": ["flow", "field"],
    "field_re_edit": ["flow", "field", "count"],
    "nav_back": ["from_screen", "in_flow"],
    "flow_cancel": ["flow", "from_screen"],
    "client_error": ["domain", "code", "screen"],
    "friction_feedback": ["flow", "from_screen", "trigger"],
    "media_upload": ["stage", "context", "bytes"],
  ]
  let actual = Dictionary(
    uniqueKeysWithValues: AnalyticsEvent.allCases.map { ($0.rawValue, $0.propertyKeys) })

  #expect(actual == expected)
}

@Test func analyticsEnumValuesMirrorBackendRegistry() {
  #expect(
    Set(AnalyticsScreen.allCases.map(\.rawValue)) == [
      "today_workout", "dashboard", "plan", "progress_history", "onboarding_wizard",
      "bind_enter_code", "pending_bind", "coach_roster", "coach_student_detail",
      "coach_receiving", "coach_planning", "coach_evaluation", "account",
    ])
  #expect(
    Set(AnalyticsFlow.allCases.map(\.rawValue)) == [
      "record_set", "onboarding", "bind", "planning", "coach_intake", "coach_feedback",
    ])
  #expect(
    Set(AnalyticsField.allCases.map(\.rawValue)) == [
      "weight", "reps", "rpe", "set_count", "bodyweight", "competition_date",
      "invite_code", "goal", "experience",
    ])
  #expect(
    Set(OnboardingStepName.allCases.map(\.rawValue)) == [
      "goal", "experience", "lifts", "schedule", "competition", "equipment", "review",
    ])
  #expect(Set(WorkoutSource.allCases.map(\.rawValue)) == ["dashboard", "calendar"])
  #expect(Set(SetOutcome.allCases.map(\.rawValue)) == ["completed", "failed"])
  #expect(Set(ProgressTab.allCases.map(\.rawValue)) == ["e1rm", "volume", "history"])
  #expect(
    Set(BindCoachStage.allCases.map(\.rawValue)) == ["invite_open", "submitted", "accepted"])
  #expect(
    Set(CoachIntakeStage.allCases.map(\.rawValue)) == [
      "request_seen", "accepted_eval", "accepted_skip", "rejected",
    ])
  #expect(Set(EvalSummaryStage.allCases.map(\.rawValue)) == ["draft_saved", "delivered"])
  #expect(Set(CoachFeedbackKind.allCases.map(\.rawValue)) == ["text", "video"])
  #expect(
    Set(MediaUploadStage.allCases.map(\.rawValue)) == ["started", "succeeded", "failed"])
  #expect(
    Set(MediaUploadContext.allCases.map(\.rawValue)) == [
      "onboarding", "set_log", "coach_feedback",
    ])
  #expect(Set(FrictionTrigger.allCases.map(\.rawValue)) == ["re_edit", "flow_cancel"])
  #expect(
    Set(ClientErrorDomain.allCases.map(\.rawValue)) == [
      "network", "decode", "persistence", "unknown", "ui",
    ])
}
