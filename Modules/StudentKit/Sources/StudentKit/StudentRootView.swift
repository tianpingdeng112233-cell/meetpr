import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct StudentRootView: View {
  private let studentID: UUID
  private let canShiftPlanDays: Bool
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let e1rm: any E1RMRepository
  private let readiness: any ReadinessRepository
  private let videoUploads: VideoUploadServices
  private let onboarding: any OnboardingRepository
  private let importedHistoryBackfill: ImportedHistoryBackfill
  private let e1rmMigration: E1RMCompetitionLiftMigration
  private let onLogout: (@MainActor () async -> Void)?
  private let trainingMode: TrainingMode
  private let soloCatalog: [Exercise]
  private let pendingSetLogCount: @Sendable (UUID) async -> Int
  private let sessionReviews: (any SessionReviewRepository)?
  private let account: (any AccountRepository)?
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var selectedTab: StudentTab = .today
  @State private var pendingPRCount = 0
  @State private var trainingTodayPulse = 0
  @State private var pendingImportedHistoryReview: PendingImportedHistoryReview?
  @State private var importedHistoryReviewQueue: [PendingImportedHistoryReview] = []
  @State private var importedHistoryRefreshToken = 0
  @State private var planRevision = 0
  @State private var isE1RMHistoryReady = false

  public init() {
    let plan = StudentDemoSeed.makePlanView()
    let store = StudentRootDemoPlanStore(studentID: StudentDemoSeed.studentID, plan: plan)
    self.init(
      studentID: StudentDemoSeed.studentID,
      canShiftPlanDays: true,
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
    canShiftPlanDays: Bool = false,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    e1rm: any E1RMRepository = LocalE1RMRepository(),
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    videoUploads: VideoUploadServices? = nil,
    onboarding: (any OnboardingRepository)? = nil,
    onLogout: (@MainActor () async -> Void)? = nil,
    trainingMode: TrainingMode = .coached,
    soloCatalog: [Exercise] = [],
    pendingSetLogCount: (@Sendable (UUID) async -> Int)? = nil,
    sessionReviews: (any SessionReviewRepository)? = nil,
    account: (any AccountRepository)? = nil
  ) {
    self.studentID = studentID
    self.canShiftPlanDays = canShiftPlanDays
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
    self.account = account
    let resolvedOnboarding =
      onboarding
      ?? InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
    self.onboarding = resolvedOnboarding
    self.importedHistoryBackfill = ImportedHistoryBackfill(
      logs: logs,
      onboarding: resolvedOnboarding,
      e1rm: e1rm,
      catalog: soloCatalog
    )
    self.e1rmMigration = E1RMCompetitionLiftMigration(
      logs: logs,
      onboarding: resolvedOnboarding,
      plans: plans,
      catalogReader: plans as? any ExerciseCatalogReading,
      fallbackCatalog: soloCatalog,
      e1rm: e1rm
    )
    self._feedbackViewModel = State(
      initialValue: FeedbackInboxViewModel(repository: feedback)
    )
  }

  public var body: some View {
    Group {
      if isE1RMHistoryReady {
        studentTabs
      } else {
        ProgressView("正在校准实力记录…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      guard !isE1RMHistoryReady else { return }
      _ = try? await e1rmMigration.runIfNeeded(studentID: studentID)
      isE1RMHistoryReady = true
    }
  }

  private var studentTabs: some View {
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
              onboarding: onboarding,
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
            canShiftPlanDays: canShiftPlanDays,
            plans: plans,
            logs: logs,
            onboarding: onboarding,
            e1rm: e1rm,
            feedbackViewModel: feedbackViewModel,
            onStartWorkout: {
              trainingTodayPulse += 1
              selectedTab = .training
            },
            onSeeAllFeedback: { selectedTab = .growth },
            onPlanChanged: { planRevision += 1 }
          )
        }
      }
      .tag(StudentTab.today)
      .tabItem {
        Label(trainingMode == .selfTrain ? "今天" : "今日", systemImage: "house")
      }

      // 训练 tab. Solo (spec 047 §3): the read-only month-grouped history —
      // there is no plan calendar to show; editing stays on 今天.
      Group {
        if trainingMode == .selfTrain {
          SoloHistoryView(
            studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
            onboarding: onboarding, sessionReviews: sessionReviews, catalog: soloCatalog
          )
        } else {
          TodayWorkoutView(
            studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
            onboarding: onboarding, readiness: readiness, videoUploads: videoUploads,
            resetToTodayPulse: trainingTodayPulse,
            sessionReviews: sessionReviews, planRevision: planRevision
          )
        }
      }
      .tag(StudentTab.training)
      .tabItem {
        Label(
          trainingMode == .selfTrain ? "历史" : "训练",
          systemImage: trainingMode == .selfTrain ? "clock" : "dumbbell.fill"
        )
      }

      // 成长 — e1RM growth + full training history + coach-feedback history all
      // live here (the 历史 tab folds in; assembled fully in a later slice).
      TrainingHistoryView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding,
        feedbackViewModel: feedbackViewModel, sessionReviews: sessionReviews,
        trainingMode: trainingMode, soloCatalog: soloCatalog,
        importedHistoryRefreshToken: importedHistoryRefreshToken,
        onImportedHistoryRefresh: { await runImportedHistoryBackfill() }
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
        onLogout: onLogout,
        trainingMode: trainingMode,
        soloCatalog: soloCatalog,
        account: account,
        logs: logs
      )
      .tag(StudentTab.profile)
      .tabItem {
        Label("我的", systemImage: "person")
      }
      .badge(pendingPRCount)
    }
    // Acking PRs on the growth tab must clear the profile badge when the
    // student switches away (spec 051 §2 — same staleness family as U6).
    .onChange(of: selectedTab) { _, tab in
      Task {
        if tab == .growth {
          await runImportedHistoryBackfill()
        }
        pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
      }
    }
    .task {
      if feedbackViewModel.state == .idle {
        await feedbackViewModel.load(studentID: studentID)
      }
      pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
      await runImportedHistoryBackfill()
    }
    .importedHistoryReviewAlert(
      review: $pendingImportedHistoryReview,
      onAnswer: answerImportedHistoryReview
    )
    .tint(Color.MeetPR.brandRed)
  }

}

extension StudentRootView {
  @MainActor
  fileprivate func runImportedHistoryBackfill() async {
    guard let result = try? await importedHistoryBackfill.backfill(studentID: studentID) else {
      return
    }
    // Queue every pending family and present the prompts one after another —
    // a multi-family import must not lose its second prompt (spec 053 §5).
    importedHistoryReviewQueue = result.pendingReviews
    if pendingImportedHistoryReview == nil {
      pendingImportedHistoryReview = importedHistoryReviewQueue.first
    }
    if result.importedPointCount > 0 {
      importedHistoryRefreshToken += 1
    }
  }

  @MainActor
  fileprivate func answerImportedHistoryReview(
    _ review: PendingImportedHistoryReview,
    decision: ImportedHistoryReviewDecision
  ) async {
    try? await importedHistoryBackfill.answer(review, decision: decision)
    importedHistoryReviewQueue.removeAll { $0.id == review.id }
    if pendingImportedHistoryReview?.id == review.id {
      pendingImportedHistoryReview = importedHistoryReviewQueue.first
    }
    importedHistoryRefreshToken += 1
  }
}

extension View {
  fileprivate func importedHistoryReviewAlert(
    review: Binding<PendingImportedHistoryReview?>,
    onAnswer:
      @escaping @MainActor (
        PendingImportedHistoryReview,
        ImportedHistoryReviewDecision
      ) async -> Void
  ) -> some View {
    alert(
      "确认导入历史",
      isPresented: Binding(
        get: { review.wrappedValue != nil },
        set: { if !$0 { review.wrappedValue = nil } }
      ),
      presenting: review.wrappedValue
    ) { pending in
      Button("确实") {
        Task { await onAnswer(pending, .confirmed) }
      }
      Button("没有", role: .destructive) {
        Task { await onAnswer(pending, .rejected) }
      }
    } message: { pending in
      Text(importedHistoryReviewMessage(pending))
    }
  }

  private func importedHistoryReviewMessage(_ review: PendingImportedHistoryReview) -> String {
    "导入的历史记录里有 \(StudentFormatting.kilograms(review.sourceWeightKg))kg × "
      + "\(review.sourceReps)(约 e1RM \(StudentFormatting.kilograms(review.sourceE1RMKg))kg),"
      + "超过你填写的 1RM \(StudentFormatting.kilograms(review.baseline1RMKg))kg——当时确实完成了吗?"
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
