import Foundation

extension Analytics {
  public func workoutLogStarted(planID: UUID? = nil, source: WorkoutSource) {
    var props: [String: AnalyticsValue] = ["source": .enumCase(source)]
    if let planID { props["plan_id"] = .id(planID) }
    track(.workoutLogStart, props: props)
  }

  public func setLogged(
    exerciseID: UUID,
    setIndex: Int,
    hasVideo: Bool,
    outcome: SetOutcome
  ) {
    track(
      .setLogged,
      props: [
        "exercise_id": .id(exerciseID),
        "set_index": .int(setIndex),
        "has_video": .bool(hasVideo),
        "outcome": .enumCase(outcome),
      ])
  }

  public func workoutLogSaved(setCount: Int, durationMilliseconds: Int) {
    track(
      .workoutLogSave,
      props: ["n_sets": .int(setCount), "duration_ms": .int(durationMilliseconds)])
  }

  public func onboardingStep(index: Int, name: OnboardingStepName) {
    track(
      .onboardingStep,
      props: ["step_index": .int(index), "step_name": .enumCase(name)])
  }

  public func onboardingCompleted(filledStepCount: Int, usedDraftResume: Bool) {
    track(
      .onboardingComplete,
      props: [
        "n_steps_filled": .int(filledStepCount),
        "used_draft_resume": .bool(usedDraftResume),
      ])
  }

  public func bindCoachAction(_ stage: BindCoachStage) {
    track(.bindCoachAction, props: ["stage": .enumCase(stage)])
  }

  public func planViewed(planID: UUID) {
    track(.planViewed, props: ["plan_id": .id(planID)])
  }

  public func progressViewed(_ tab: ProgressTab) {
    track(.progressViewed, props: ["tab": .enumCase(tab)])
  }

  public func coachOpenedStudent(id: UUID) {
    track(.coachOpenStudent, props: ["student_id": .id(id)])
  }

  public func coachFeedbackSent(studentID: UUID, kind: CoachFeedbackKind) {
    track(
      .coachFeedbackSent,
      props: ["student_id": .id(studentID), "kind": .enumCase(kind)])
  }

  public func coachPlanAssigned(studentID: UUID) {
    track(.coachPlanAssigned, props: ["student_id": .id(studentID)])
  }

  public func coachIntakeAction(_ stage: CoachIntakeStage, studentID: UUID) {
    track(
      .coachIntakeAction,
      props: ["stage": .enumCase(stage), "student_id": .id(studentID)])
  }

  public func validationError(flow: AnalyticsFlow, field: AnalyticsField) {
    track(
      .validationError,
      props: ["flow": .enumCase(flow), "field": .enumCase(field)])
  }

  public func navigationBack(from screen: AnalyticsScreen, in flow: AnalyticsFlow) {
    track(
      .navBack,
      props: ["from_screen": .enumCase(screen), "in_flow": .enumCase(flow)])
  }

  public func mediaUpload(
    _ stage: MediaUploadStage,
    context: MediaUploadContext,
    bytes: Int? = nil
  ) {
    var props: [String: AnalyticsValue] = [
      "stage": .enumCase(stage), "context": .enumCase(context),
    ]
    if let bytes { props["bytes"] = .int(bytes) }
    track(.mediaUpload, props: props)
  }
}
