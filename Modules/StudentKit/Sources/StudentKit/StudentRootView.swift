import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct StudentRootView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  @State private var feedbackViewModel: FeedbackInboxViewModel

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
    TabView {
      TodayWorkoutView(studentID: studentID, plans: plans, logs: logs)
        .tabItem {
          Label("今天", systemImage: "figure.strengthtraining.traditional")
        }

      WeekOverviewView(studentID: studentID, plans: plans, logs: logs)
        .tabItem {
          Label("本周", systemImage: "calendar")
        }

      TrainingHistoryView(studentID: studentID, plans: plans, logs: logs)
        .tabItem {
          Label("历史", systemImage: "clock.arrow.circlepath")
        }

      FeedbackInboxView(studentID: studentID, viewModel: feedbackViewModel)
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
  }
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
