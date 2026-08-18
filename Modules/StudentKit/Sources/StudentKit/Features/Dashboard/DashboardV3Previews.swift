#if DEBUG
  import CoreModels
  import DesignSystem
  import RepositoryContracts
  import SwiftUI

  @available(iOS 17.0, macOS 14.0, *)
  private enum DashboardPreviewScenario {
    case normal
    case completed
    case feedbackExpanded
    case noFeedback

    var expandsFeedback: Bool {
      self == .feedbackExpanded
    }

    var hidesFeedback: Bool {
      self == .noFeedback
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private struct DashboardV3Preview: View {
    let scenario: DashboardPreviewScenario

    @State private var isFeedbackExpanded: Bool
    @State private var plan: StudentPlanView

    private let previewNow: Date
    init(scenario: DashboardPreviewScenario) {
      let seedPlan = StudentDemoSeed.makePlanView()
      let normalDate = seedPlan.days[4].date
      let previewNow = normalDate
      self.scenario = scenario
      self.previewNow = previewNow
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
              coachName: StudentStrings.localized(.dashboardV3Previews001),
              newPRCount: 0,
              showsNotifications: true,
              notificationUnreadCount: 3,
              isLoading: false,
              now: previewNow
            ),
            feedbackViewModel: nil,
            isFeedbackExpanded: $isFeedbackExpanded,
            onOpenNotifications: {},
            onStartWorkout: {},
            isUpdatingCompletion: false,
            onUndoCompletion: { _ in },
            onMessageCoach: {}
          )
        }
        .scrollIndicators(.hidden)
        .background(Color.MeetPR.bgBase)
        .hideNavigationBar()
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

  #Preview(StudentStrings.localized(.dashboardV3Previews002)) {
    DashboardV3Preview(scenario: .normal)
      .preferredColorScheme(.dark)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews003)) {
    DashboardV3Preview(scenario: .normal)
      .preferredColorScheme(.light)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews004)) {
    DashboardV3Preview(scenario: .completed)
      .preferredColorScheme(.light)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews005)) {
    DashboardV3Preview(scenario: .feedbackExpanded)
      .preferredColorScheme(.dark)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews006)) {
    DashboardV3Preview(scenario: .feedbackExpanded)
      .preferredColorScheme(.light)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews007)) {
    DashboardV3Preview(scenario: .noFeedback)
      .preferredColorScheme(.dark)
  }

  #Preview(StudentStrings.localized(.dashboardV3Previews008)) {
    DashboardV3Preview(scenario: .noFeedback)
      .preferredColorScheme(.light)
  }
#endif
