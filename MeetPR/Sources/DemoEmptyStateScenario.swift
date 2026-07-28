#if DEMO_MODE
  import AppShell
  import ChatUI
  import CoachKit
  import CoreModels
  import Foundation
  import StudentKit

  enum DemoEmptyStateScenario: String {
    case feedbackPending = "feedback-pending"
    case nextPlanPending = "next-plan-pending"
    case restDay = "rest-day"
    case growthForming = "growth-forming"
    case growthZero = "growth-zero"
    case planUnavailable = "plan-unavailable"
    case emptyConversation = "empty-conversation"

    static var launchValue: Self? {
      let arguments = ProcessInfo.processInfo.arguments
      guard
        let flagIndex = arguments.firstIndex(of: "-student-empty-state"),
        arguments.indices.contains(flagIndex + 1)
      else {
        return nil
      }
      return Self(rawValue: arguments[flagIndex + 1])
    }
  }

  struct DemoEvaluationFunnel {
    let bindQueue: InMemoryCoachBindQueueRepository
    let evaluations: InMemoryCoachEvaluationRepository
    let summaries: InMemoryCoachEvaluationSummaryRepository
    let profiles: InMemoryCoachStudentProfileReader
  }

  struct DemoChatDependencies {
    let session: Session
    let controller: ChatSessionController
    let repository: InMemoryChatRepository
  }

  struct DemoStudentState {
    private struct Components {
      let plan: StudentPlanView?
      let logs: [StudentSetLog]
      let feedback: [CoachFeedback]
      let e1rmPoints: [E1RMHistoryPoint]
      let prEvents: [PRBreakthroughEvent]
    }

    let plan: StudentPlanView?
    let logs: [StudentSetLog]
    let feedback: [CoachFeedback]
    let e1rmPoints: [E1RMHistoryPoint]
    let prEvents: [PRBreakthroughEvent]
    let profile: OnboardingProfile
    let hasEmptyConversation: Bool

    static func make(
      scenario: DemoEmptyStateScenario?,
      includesTodayByDefault: Bool
    ) -> Self {
      switch scenario {
      case .feedbackPending:
        feedbackPendingState()
      case .nextPlanPending:
        nextPlanPendingState()
      case .restDay:
        restDayState()
      case .growthForming:
        growthFormingState()
      case .growthZero:
        growthZeroState()
      case .planUnavailable:
        unavailablePlanState(emptyConversation: false)
      case .emptyConversation:
        unavailablePlanState(emptyConversation: true)
      case nil:
        defaultState(includesToday: includesTodayByDefault)
      }
    }

    private static func feedbackPendingState() -> Self {
      let plan = StudentDemoSeed.makePlanView()
      return state(
        Components(
          plan: plan,
          logs: StudentDemoSeed.makeSubmittedTodayLogs(plan: plan),
          feedback: historicalResponseFeedback(),
          e1rmPoints: standardE1RM(),
          prEvents: []
        ),
        scenario: .feedbackPending
      )
    }

    private static func nextPlanPendingState() -> Self {
      let plan = StudentDemoSeed.makePlanEndingToday()
      return state(
        Components(
          plan: plan,
          logs: StudentDemoSeed.makeAllCompletedLogs(plan: plan),
          feedback: StudentDemoSeed.makeFeedback(),
          e1rmPoints: standardE1RM(),
          prEvents: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
        ),
        scenario: .nextPlanPending
      )
    }

    private static func restDayState() -> Self {
      let plan = StudentDemoSeed.makeRestDayPlan()
      return state(
        Components(
          plan: plan,
          logs: StudentDemoSeed.makeAllCompletedLogs(plan: plan),
          feedback: StudentDemoSeed.makeFeedback(),
          e1rmPoints: standardE1RM(),
          prEvents: []
        ),
        scenario: .restDay
      )
    }

    private static func growthFormingState() -> Self {
      let plan = StudentDemoSeed.makePlanView()
      return state(
        Components(
          plan: plan,
          logs: StudentDemoSeed.makeSingleSessionLogs(plan: plan),
          feedback: [],
          e1rmPoints: StudentDemoSeed.makeFormingE1RMHistory(),
          prEvents: []
        ),
        scenario: .growthForming
      )
    }

    private static func growthZeroState() -> Self {
      state(
        Components(
          plan: StudentDemoSeed.makePlanView(),
          logs: [],
          feedback: [],
          e1rmPoints: [],
          prEvents: []
        ),
        scenario: .growthZero
      )
    }

    private static func unavailablePlanState(emptyConversation: Bool) -> Self {
      state(
        Components(
          plan: nil,
          logs: [],
          feedback: [],
          e1rmPoints: [],
          prEvents: []
        ),
        scenario: emptyConversation ? .emptyConversation : .planUnavailable
      )
    }

    private static func defaultState(includesToday: Bool) -> Self {
      state(
        Components(
          plan: StudentDemoSeed.makePlanView(),
          logs: StudentDemoSeed.makeHistoricalLogs(
            studentID: StudentDemoSeed.studentID,
            includeToday: includesToday
          ),
          feedback: StudentDemoSeed.makeFeedback(),
          e1rmPoints: standardE1RM(),
          prEvents: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
        ),
        scenario: nil
      )
    }

    private static func standardE1RM() -> [E1RMHistoryPoint] {
      StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID)
    }

    private static func historicalResponseFeedback() -> [CoachFeedback] {
      StudentDemoSeed.makeFeedback().map { feedback in
        CoachFeedback(
          id: feedback.id,
          coachID: feedback.coachID,
          studentID: feedback.studentID,
          dayDate: nil,
          planExerciseID: nil,
          videoID: feedback.videoID,
          video: feedback.video,
          text: feedback.text,
          postedAt: feedback.postedAt,
          readAt: feedback.readAt
        )
      }
    }

    private static func state(
      _ components: Components,
      scenario: DemoEmptyStateScenario?
    ) -> Self {
      Self(
        plan: components.plan,
        logs: components.logs,
        feedback: components.feedback,
        e1rmPoints: components.e1rmPoints,
        prEvents: components.prEvents,
        profile: StudentDemoSeed.makeOnboardingProfile(
          studentID: StudentDemoSeed.studentID,
          isCompeting: scenario != .nextPlanPending
        ),
        hasEmptyConversation: scenario == .emptyConversation
      )
    }
  }
#endif
