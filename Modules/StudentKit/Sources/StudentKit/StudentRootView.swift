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
  private let e1rm: any E1RMRepository
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var selectedTab: StudentTab = .dashboard
  @State private var pendingPRCount = 0

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
      ),
      e1rm: InMemoryE1RMRepository(
        seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
        seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
      )
    )
  }

  public init(
    studentID: UUID = StudentDemoSeed.studentID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    e1rm: any E1RMRepository = LocalE1RMRepository()
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.e1rm = e1rm
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

      TodayWorkoutView(studentID: studentID, plans: plans, logs: logs, e1rm: e1rm)
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

      MyProfileView(studentID: studentID, plans: plans, e1rm: e1rm)
        .tag(StudentTab.profile)
        .tabItem {
          Label("我的", systemImage: "person")
        }
        .badge(pendingPRCount)
    }
    .task {
      if feedbackViewModel.state == .idle {
        await feedbackViewModel.load(studentID: studentID)
      }
      pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
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
  case profile
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
