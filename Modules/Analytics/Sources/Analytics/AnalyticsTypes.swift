import Foundation

public enum AnalyticsEvent: String, Codable, CaseIterable, Sendable {
  case appOpen = "app_open"
  case screenView = "screen_view"
  case workoutLogStart = "workout_log_start"
  case setLogged = "set_logged"
  case workoutLogSave = "workout_log_save"
  case onboardingStep = "onboarding_step"
  case onboardingComplete = "onboarding_complete"
  case bindCoachAction = "bind_coach_action"
  case planViewed = "plan_viewed"
  case progressViewed = "progress_viewed"
  case coachOpenStudent = "coach_open_student"
  case coachFeedbackSent = "coach_feedback_sent"
  case coachPlanAssigned = "coach_plan_assigned"
  case coachIntakeAction = "coach_intake_action"
  case evalSummaryAction = "eval_summary_action"
  case validationError = "validation_error"
  case fieldReEdit = "field_re_edit"
  case navBack = "nav_back"
  case flowCancel = "flow_cancel"
  case clientError = "client_error"
  case frictionFeedback = "friction_feedback"
  case mediaUpload = "media_upload"
}

public enum AnalyticsScreen: String, Codable, CaseIterable, Sendable {
  case todayWorkout = "today_workout"
  case dashboard
  case plan
  case progressHistory = "progress_history"
  case onboardingWizard = "onboarding_wizard"
  case bindEnterCode = "bind_enter_code"
  case pendingBind = "pending_bind"
  case coachRoster = "coach_roster"
  case coachStudentDetail = "coach_student_detail"
  case coachReceiving = "coach_receiving"
  case coachPlanning = "coach_planning"
  case coachEvaluation = "coach_evaluation"
  case account
}

public enum AnalyticsFlow: String, Codable, CaseIterable, Sendable {
  case recordSet = "record_set"
  case onboarding
  case bind
  case planning
  case coachIntake = "coach_intake"
  case coachFeedback = "coach_feedback"
}

public enum AnalyticsField: String, Codable, CaseIterable, Sendable {
  case weight
  case reps
  case rpe
  case setCount = "set_count"
  case bodyweight
  case competitionDate = "competition_date"
  case inviteCode = "invite_code"
  case goal
  case experience
}

public enum AnalyticsFlowStep: String, Codable, CaseIterable, Sendable {
  case start
  case step
  case cancel
  case complete
}

public enum OnboardingStepName: String, Codable, CaseIterable, Sendable {
  case goal
  case experience
  case lifts
  case schedule
  case competition
  case equipment
  case review
}

public enum FrictionTrigger: String, Codable, CaseIterable, Sendable {
  case reEdit = "re_edit"
  case flowCancel = "flow_cancel"
}

public enum WorkoutSource: String, CaseIterable, Sendable { case dashboard, calendar }
public enum SetOutcome: String, CaseIterable, Sendable { case completed, failed }
public enum ProgressTab: String, CaseIterable, Sendable { case e1rm, volume, history }
public enum BindCoachStage: String, CaseIterable, Sendable {
  case inviteOpen = "invite_open"
  case submitted, accepted
}
public enum CoachIntakeStage: String, CaseIterable, Sendable {
  case requestSeen = "request_seen"
  case acceptedEvaluation = "accepted_eval"
  case acceptedSkip = "accepted_skip"
  case rejected
}
public enum EvalSummaryStage: String, CaseIterable, Sendable {
  case draftSaved = "draft_saved"
  case delivered
}
public enum CoachFeedbackKind: String, CaseIterable, Sendable { case text, video }
public enum MediaUploadStage: String, CaseIterable, Sendable { case started, succeeded, failed }
public enum MediaUploadContext: String, CaseIterable, Sendable {
  case onboarding
  case setLog = "set_log"
  case coachFeedback = "coach_feedback"
}
public enum ClientErrorDomain: String, CaseIterable, Sendable {
  case network, decode, persistence, unknown
  case userInterface = "ui"
}

public enum AnalyticsMode: Sendable {
  case live
  case disabled
}

public enum AnalyticsValue: Codable, Equatable, Sendable {
  case id(UUID)
  case int(Int)
  case bool(Bool)
  case enumCase(String)

  public static func enumCase<T: RawRepresentable & Sendable>(_ value: T) -> Self
  where T.RawValue == String {
    .enumCase(value.rawValue)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else {
      let value = try container.decode(String.self)
      self = UUID(uuidString: value).map(Self.id) ?? .enumCase(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .id(let value): try container.encode(value.uuidString.lowercased())
    case .int(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .enumCase(let value): try container.encode(value)
    }
  }
}

public typealias EventTransport =
  @Sendable (_ request: URLRequest, _ body: Data) async throws -> (Data, URLResponse)

extension AnalyticsEvent {
  var propertyKeys: Set<String> {
    switch self {
    case .appOpen: ["cold"]
    case .screenView: ["screen"]
    case .workoutLogStart: ["plan_id", "source"]
    case .setLogged: ["exercise_id", "set_index", "has_video", "outcome"]
    case .workoutLogSave: ["n_sets", "duration_ms"]
    case .onboardingStep: ["step_index", "step_name"]
    case .onboardingComplete: ["n_steps_filled", "used_draft_resume"]
    case .bindCoachAction: ["stage"]
    case .planViewed: ["plan_id"]
    case .progressViewed: ["tab"]
    case .coachOpenStudent: ["student_id"]
    case .coachFeedbackSent: ["student_id", "kind"]
    case .coachPlanAssigned: ["student_id"]
    case .coachIntakeAction: ["stage", "student_id"]
    case .evalSummaryAction: ["stage", "student_id"]
    case .validationError: ["flow", "field"]
    case .fieldReEdit: ["flow", "field", "count"]
    case .navBack: ["from_screen", "in_flow"]
    case .flowCancel: ["flow", "from_screen"]
    case .clientError: ["domain", "code", "screen"]
    case .frictionFeedback: ["flow", "from_screen", "trigger"]
    case .mediaUpload: ["stage", "context", "bytes"]
    }
  }
}
