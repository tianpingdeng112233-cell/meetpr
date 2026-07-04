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
  private let readiness: any ReadinessRepository
  private let videoUploads: VideoUploadServices
  private let onboarding: any OnboardingRepository
  private let onLogout: (@MainActor () async -> Void)?
  private let trainingMode: TrainingMode
  private let soloCatalog: [Exercise]
  private let pendingSetLogCount: @Sendable (UUID) async -> Int
  private let sessionReviews: (any SessionReviewRepository)?
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var evaluationSummaryViewModel: StudentEvaluationSummaryViewModel
  @State private var selectedTab: StudentTab = .today
  @State private var pendingPRCount = 0
  @State private var trainingTodayPulse = 0

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
      ),
      readiness: InMemoryReadinessRepository(
        seed: StudentDemoSeed.makeReadinessHistory(studentID: StudentDemoSeed.studentID)
      )
    )
  }

  public init(
    studentID: UUID = StudentDemoSeed.studentID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    e1rm: any E1RMRepository = LocalE1RMRepository(),
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    videoUploads: VideoUploadServices? = nil,
    onboarding: (any OnboardingRepository)? = nil,
    evaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    summaryReadStore: (any EvaluationSummaryReadStoring)? = nil,
    onLogout: (@MainActor () async -> Void)? = nil,
    trainingMode: TrainingMode = .coached,
    soloCatalog: [Exercise] = [],
    pendingSetLogCount: (@Sendable (UUID) async -> Int)? = nil,
    sessionReviews: (any SessionReviewRepository)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.e1rm = e1rm
    self.readiness = readiness
    self.videoUploads = videoUploads ?? .demo()
    self.onLogout = onLogout
    self.trainingMode = trainingMode
    self.soloCatalog = soloCatalog
    self.pendingSetLogCount = pendingSetLogCount ?? { _ in 0 }
    self.sessionReviews = sessionReviews
    self.onboarding =
      onboarding
      ?? InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
    self._feedbackViewModel = State(
      initialValue: FeedbackInboxViewModel(repository: feedback)
    )
    self._evaluationSummaryViewModel = State(
      initialValue: StudentEvaluationSummaryViewModel(
        summaries: evaluationSummaries ?? InMemoryEvaluationSummaryRepository(),
        plans: plans,
        readStore: summaryReadStore ?? UserDefaultsEvaluationSummaryReadStore()
      )
    )
  }

  public var body: some View {
    TabView(selection: $selectedTab) {
      // 今日 — student home. Coached: the plan-driven dashboard (merges the
      // old 仪表盘 + 计划). Solo (spec 045): the adhoc session home — no plan
      // concepts anywhere on it.
      Group {
        if trainingMode == .selfTrain {
          SoloTodayView(
            viewModel: SoloSessionViewModel(
              studentID: studentID,
              logs: logs,
              e1rm: e1rm,
              catalog: soloCatalog,
              pendingCount: pendingSetLogCount
            ),
            catalog: soloCatalog,
            makeReviewViewModel: sessionReviews.map { repo in
              let studentID = self.studentID
              return {
                SessionReviewSubmitViewModel(
                  repository: repo,
                  studentID: studentID,
                  reviewDate: SoloSessionViewModel.dayString(Date(), calendar: .current)
                )
              }
            }
          )
        } else {
          DashboardView(
            studentID: studentID,
            plans: plans,
            logs: logs,
            onboarding: onboarding,
            e1rm: e1rm,
            feedbackViewModel: feedbackViewModel,
            evaluationSummaryViewModel: evaluationSummaryViewModel,
            onStartWorkout: {
              trainingTodayPulse += 1
              selectedTab = .training
            },
            onSeeAllFeedback: { selectedTab = .growth }
          )
        }
      }
      .tag(StudentTab.today)
      .tabItem {
        Label(trainingMode == .selfTrain ? "今天" : "今日", systemImage: "house")
      }

      TodayWorkoutView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm, readiness: readiness,
        videoUploads: videoUploads, resetToTodayPulse: trainingTodayPulse,
        sessionReviews: sessionReviews
      )
      .tag(StudentTab.training)
      .tabItem {
        Label("训练", systemImage: "dumbbell.fill")
      }

      // 成长 — e1RM growth + full training history + coach-feedback history all
      // live here (the 历史 tab folds in; assembled fully in a later slice).
      TrainingHistoryView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        feedbackViewModel: feedbackViewModel, sessionReviews: sessionReviews
      )
      .tag(StudentTab.growth)
      .tabItem {
        Label("成长", systemImage: "chart.line.uptrend.xyaxis")
      }

      MyProfileView(
        studentID: studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding,
        evaluationSummaryViewModel: evaluationSummaryViewModel,
        onLogout: onLogout,
        trainingMode: trainingMode
      )
      .tag(StudentTab.profile)
      .tabItem {
        Label("我的", systemImage: "person")
      }
      // PR acknowledgements + unread evaluation summary red dot (spec 033 D7).
      // Feedback unread now surfaces via the 今日 notification bell, not a tab badge.
      .badge(pendingPRCount + evaluationSummaryViewModel.unreadBadgeCount)
    }
    // Acking PRs on the growth tab must clear the profile badge when the
    // student switches away (spec 051 §2 — same staleness family as U6).
    .onChange(of: selectedTab) { _, _ in
      Task {
        pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
      }
    }
    .task {
      if feedbackViewModel.state == .idle {
        await feedbackViewModel.load(studentID: studentID)
      }
      await evaluationSummaryViewModel.load(studentID: studentID)
      pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
    }
    .tint(Color.MeetPR.brandRed)
  }
}

private enum StudentTab: Hashable {
  case today
  case training
  case growth
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
