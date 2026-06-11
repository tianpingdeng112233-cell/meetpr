import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct StudentRootView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var selectedTab: StudentTab = .dashboard

  public init() {
    let plan = StudentDemoSeed.makePlanView()
    let store = StudentRootDemoPlanStore(studentID: StudentDemoSeed.studentID, plan: plan)
    self.init(
      studentID: StudentDemoSeed.studentID,
      plans: InMemoryStudentPlanRepository(store: store),
      logs: InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
      ),
      feedback: InMemoryStudentFeedbackRepository(
        seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
      )
    )
  }

  public init(
    studentID: UUID = StudentDemoSeed.studentID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self._feedbackViewModel = State(
      initialValue: FeedbackInboxViewModel(repository: feedback)
    )
  }

  public var body: some View {
    TabView(selection: $selectedTab) {
      DashboardView(
        studentID: studentID,
        plans: plans,
        logs: logs,
        feedbackViewModel: feedbackViewModel,
        onStartWorkout: { selectedTab = .workout },
        onSeeAllFeedback: { selectedTab = .feedback }
      )
      .tag(StudentTab.dashboard)
      .tabItem {
        Label("仪表盘", systemImage: "square.grid.2x2.fill")
      }

      TodayWorkoutView(studentID: studentID, plans: plans, logs: logs)
        .tag(StudentTab.workout)
        .tabItem {
          Label("锻炼", systemImage: "figure.strengthtraining.traditional")
        }

      TrainingHistoryView(studentID: studentID, plans: plans, logs: logs)
        .tag(StudentTab.history)
        .tabItem {
          Label("历史", systemImage: "clock.arrow.circlepath")
        }

      FeedbackInboxView(studentID: studentID, viewModel: feedbackViewModel)
        .tag(StudentTab.feedback)
        .tabItem {
          Label("反馈", systemImage: "bubble.left")
        }
        .badge(feedbackViewModel.unreadCount)
    }
    .task {
      if feedbackViewModel.state == .idle {
        await feedbackViewModel.load(studentID: studentID)
      }
    }
    .tint(Color.MeetPR.brandRed)
    .preferredColorScheme(.dark)
  }
}

private enum StudentTab: Hashable {
  case dashboard
  case workout
  case history
  case feedback
}

private actor StudentRootDemoPlanStore: StudentPlanStore {
  private let studentID: UUID
  private let plan: StudentPlanView

  init(studentID: UUID, plan: StudentPlanView) {
    self.studentID = studentID
    self.plan = plan
  }

  func savePublishedProjection(_ projection: StudentPlanView, forStudent studentID: UUID) async {}

  func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
    studentID == self.studentID ? plan : nil
  }
}
