#if DEBUG
  import CoreModels
  import DesignSystem
  import RepositoryContracts
  import SwiftUI

  @available(iOS 17.0, macOS 14.0, *)
  private enum DashboardPreviewScenario {
    case normal
    case rest
    case postponed
    case feedbackExpanded
    case noFeedback

    var expandsFeedback: Bool {
      self == .feedbackExpanded
    }

    var isPostponed: Bool {
      self == .postponed
    }

    var hidesFeedback: Bool {
      self == .noFeedback
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private struct DashboardV3Preview: View {
    let scenario: DashboardPreviewScenario

    @State private var selectedDate: Date?
    @State private var isFeedbackExpanded: Bool
    @State private var plan: StudentPlanView

    private let previewNow: Date
    private let plans: InMemoryStudentPlanRepository

    init(scenario: DashboardPreviewScenario) {
      let seedPlan = StudentDemoSeed.makePlanView()
      let normalDate = seedPlan.days[4].date
      let previewNow = scenario == .rest ? seedPlan.days[2].date : normalDate
      let store = DashboardPreviewPlanStore(
        studentID: StudentDemoSeed.studentID,
        plan: seedPlan
      )
      self.scenario = scenario
      self.previewNow = previewNow
      self.plans = InMemoryStudentPlanRepository(
        store: store,
        now: { previewNow }
      )
      self._selectedDate = State(initialValue: previewNow)
      self._isFeedbackExpanded = State(initialValue: scenario.expandsFeedback)
      self._plan = State(initialValue: seedPlan)
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          DashboardTodayScreen(
            model: DashboardTodayScreenModel(
              weekIndex: plan.weekIndex,
              planStartDate: plan.startDate,
              planEndDate: plan.endDate,
              days: plan.days,
              cycleDays: plan.days,
              logs: [],
              feedbackItems: scenario.hidesFeedback
                ? []
                : StudentDemoSeed.makeFeedback(),
              isFeedbackLoaded: true,
              trendRows: trendRows,
              metrics: DashboardProfileMetrics(
                bodyWeightText: "83 kg",
                competition: CompetitionCountdown(days: 3, dateText: "2026-07-29")
              ),
              coachName: "演示教练",
              newPRCount: 0,
              showsNotifications: true,
              notificationUnreadCount: 3,
              canShiftPlanDays: true,
              canUndoPlanShift: PlanDayShiftLogic.canUndo(
                latestShiftCreatedAt: plan.latestShiftCreatedAt,
                now: previewNow
              ),
              isUpdatingDayShift: false,
              isLoading: false,
              now: previewNow
            ),
            feedbackViewModel: nil,
            selectedDate: $selectedDate,
            isFeedbackExpanded: $isFeedbackExpanded,
            onOpenNotifications: {},
            onStartWorkout: {},
            onStartWorkoutFrameChange: { _ in },
            isStartWorkoutHidden: false,
            onShiftPlan: {},
            onUndoShift: {},
            onMessageCoach: {}
          )
        }
        .scrollIndicators(.hidden)
        .background(Color.MeetPR.bgBase)
        .hideNavigationBar()
      }
      .task(id: scenario.isPostponed) {
        guard scenario.isPostponed, plan.latestShiftCreatedAt == nil else { return }
        _ = try? await plans.shiftPlan(
          id: plan.cycleID,
          studentID: StudentDemoSeed.studentID
        )
        if let shiftedPlan = try? await plans.fetchCurrentPlan(
          studentID: StudentDemoSeed.studentID
        ) {
          plan = shiftedPlan
        }
      }
    }

    private var trendRows: [DashboardE1RMTrendRow] {
      let points = StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID)
      let families: [LiftFamily] = [.squat, .bench, .deadlift]
      return families.map { family in
        let familyPoints = points.filter { point in
          switch family {
          case .squat: point.e1RMKg >= 100 && point.e1RMKg < 150
          case .bench: point.e1RMKg < 100
          case .deadlift: point.e1RMKg >= 150
          }
        }
        return DashboardE1RMTrendRow(
          family: family,
          points: familyPoints,
          smoothedSamples: [],
          rawEligiblePoints: [],
          eligibleRecordCount: familyPoints.count,
          latestDisplayDate: familyPoints.map(\.computedAt).max(),
          latestRecordPoint: familyPoints.max { $0.computedAt < $1.computedAt }
        )
      }
    }
  }

  private actor DashboardPreviewPlanStore: StudentPlanStore {
    private let studentID: UUID
    private var plan: StudentPlanView

    init(studentID: UUID, plan: StudentPlanView) {
      self.studentID = studentID
      self.plan = plan
    }

    func savePublishedProjection(
      _ projection: StudentPlanView,
      forStudent studentID: UUID
    ) async {
      guard studentID == self.studentID else { return }
      plan = projection
    }

    func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
      studentID == self.studentID ? plan : nil
    }
  }

  #Preview("W2a · 正常日 · Dark") {
    DashboardV3Preview(scenario: .normal)
      .preferredColorScheme(.dark)
  }

  #Preview("W2a · 正常日 · Light") {
    DashboardV3Preview(scenario: .normal)
      .preferredColorScheme(.light)
  }

  #Preview("W2a · 休息日/无计划 · Dark") {
    DashboardV3Preview(scenario: .rest)
      .preferredColorScheme(.dark)
  }

  #Preview("W2a · 休息日/无计划 · Light") {
    DashboardV3Preview(scenario: .rest)
      .preferredColorScheme(.light)
  }

  #Preview("W2a · 已顺延 · Dark") {
    DashboardV3Preview(scenario: .postponed)
      .preferredColorScheme(.dark)
  }

  #Preview("W2a · 已顺延 · Light") {
    DashboardV3Preview(scenario: .postponed)
      .preferredColorScheme(.light)
  }

  #Preview("W2a · 反馈展开 · Dark") {
    DashboardV3Preview(scenario: .feedbackExpanded)
      .preferredColorScheme(.dark)
  }

  #Preview("W2a · 反馈展开 · Light") {
    DashboardV3Preview(scenario: .feedbackExpanded)
      .preferredColorScheme(.light)
  }

  #Preview("W2a · 无反馈 · Dark") {
    DashboardV3Preview(scenario: .noFeedback)
      .preferredColorScheme(.dark)
  }

  #Preview("W2a · 无反馈 · Light") {
    DashboardV3Preview(scenario: .noFeedback)
      .preferredColorScheme(.light)
  }
#endif
