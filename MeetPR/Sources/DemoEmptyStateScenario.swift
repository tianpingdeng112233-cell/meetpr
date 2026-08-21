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
    case pctAnchors = "pct-anchors"

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

  // Scenario factories intentionally stay together so one launch flag maps to
  // one self-contained, deterministic student state.
  // swiftlint:disable:next type_body_length
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
      case .pctAnchors:
        percentageAnchorState()
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

    private static func percentageAnchorState() -> Self {
      let plan = percentageAnchorPlan()
      return state(
        Components(
          plan: plan,
          logs: [percentageAnchorTopSetLog(plan: plan)],
          feedback: [],
          e1rmPoints: [],
          prEvents: []
        ),
        scenario: .pctAnchors
      )
    }

    private static func percentageAnchorTopSetLog(plan: StudentPlanView) -> StudentSetLog {
      let deadlift = plan.days[0].exercises[1]
      return StudentSetLog(
        id: demoID(601),
        studentID: StudentDemoSeed.studentID,
        planExerciseID: deadlift.id,
        exerciseID: deadlift.exercise.id,
        setIndex: 0,
        loggedAt: plan.days[0].scheduledDate.addingTimeInterval(3_600),
        weightKg: 150,
        reps: 1,
        rpe: 8,
        completed: true
      )
    }

    // swiftlint:disable:next function_body_length
    private static func percentageAnchorPlan() -> StudentPlanView {
      let today = Calendar.current.startOfDay(for: Date())
      let squat = percentageAnchorExercise(
        id: demoID(1),
        exerciseID: demoID(11),
        name: "竞技深蹲",
        nameEn: "Competition Squat",
        family: .squat,
        sequenceIndex: 0,
        sets: [
          PrescribedSet(
            id: demoID(101), setIndex: 0, intensity: .percentage(60),
            percentageAnchor: .registeredOneRM, loadMode: .percentage, reps: 5),
          PrescribedSet(
            id: demoID(102), setIndex: 1, intensity: .percentage(75),
            percentageAnchor: .registeredOneRM, loadMode: .percentage, reps: 3),
        ]
      )
      // The web editor keys load_mode/pct_anchor per row, so a coach writes the
      // top set and its back-offs as two rows of the same exercise — spec 034
      // §9.4's "preceding rows" rule only resolves across rows.
      let deadliftTopSet = percentageAnchorExercise(
        id: demoID(2),
        exerciseID: demoID(12),
        name: "传统硬拉",
        nameEn: "Conventional Deadlift",
        family: .deadlift,
        sequenceIndex: 1,
        sets: [
          PrescribedSet(
            id: demoID(201), setIndex: 0, intensity: .rpe(8), loadMode: .rpe, reps: 1)
        ]
      )
      let deadliftBackoff = percentageAnchorExercise(
        id: demoID(4),
        exerciseID: demoID(12),
        name: "传统硬拉",
        nameEn: "Conventional Deadlift",
        family: .deadlift,
        sequenceIndex: 2,
        sets: [
          PrescribedSet(
            id: demoID(202), setIndex: 0, intensity: .percentage(85),
            percentageAnchor: .topSet, loadMode: .percentage, reps: 5),
          PrescribedSet(
            id: demoID(203), setIndex: 1, intensity: .percentage(85),
            percentageAnchor: .topSet, loadMode: .percentage, reps: 5),
        ]
      )
      let accessory = percentageAnchorExercise(
        id: demoID(3),
        exerciseID: demoID(13),
        name: "山羊挺身",
        nameEn: "Back Extension",
        family: nil,
        sequenceIndex: 3,
        sets: [
          PrescribedSet(
            id: demoID(301), setIndex: 0, intensity: .percentage(60),
            percentageAnchor: .registeredOneRM, loadMode: .percentage, reps: 12)
        ]
      )
      let day = StudentPlanDay(
        id: demoID(401),
        date: today,
        exercises: [squat, deadliftTopSet, deadliftBackoff, accessory]
      )
      return StudentPlanView(
        cycleID: demoID(501),
        weekIndex: 1,
        startDate: today,
        endDate: today,
        publishedAt: today,
        days: [day]
      )
    }

    // swiftlint:disable:next function_parameter_count
    private static func percentageAnchorExercise(
      id: UUID,
      exerciseID: UUID,
      name: String,
      nameEn: String,
      family: LiftFamily?,
      sequenceIndex: Int,
      sets: [PrescribedSet]
    ) -> StudentPlanExercise {
      StudentPlanExercise(
        id: id,
        exercise: Exercise(
          id: exerciseID,
          name: name,
          nameEn: nameEn,
          exerciseType: family == nil ? .accessory : .mainLift,
          mainLiftFamily: family,
          isCompetitionLift: family != nil,
          muscleGroups: family == nil ? [.back] : [.glute, .back],
          equipment: family == nil ? [.machine] : [.barbell],
          createdAt: StudentDemoSeed.referenceDate
        ),
        sequenceIndex: sequenceIndex,
        prescribedSets: sets
      )
    }

    private static func demoID(_ value: Int) -> UUID {
      let digits = String(value)
      let suffix = String(repeating: "0", count: max(0, 12 - digits.count)) + digits
      guard
        let id = UUID(
          uuidString: "07200000-0000-0000-0000-\(suffix)"
        )
      else {
        preconditionFailure("Invalid pct-anchor demo UUID")
      }
      return id
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
          isCompeting: scenario != .nextPlanPending,
          squat1RMKg: scenario == .pctAnchors ? 200 : 180
        ),
        hasEmptyConversation: scenario == .emptyConversation
      )
    }
  }
#endif
