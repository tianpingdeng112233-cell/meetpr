#if DEBUG
  import CoreModels
  import RepositoryContracts
  import SwiftUI

  @available(iOS 17.0, macOS 14.0, *)
  private struct GrowthV3Preview: View {
    let hasData: Bool

    private let plans: InMemoryStudentPlanRepository
    private let logs: InMemoryStudentTrainingLogRepository
    private let e1rm: InMemoryE1RMRepository
    private let onboarding: InMemoryOnboardingRepository
    private let feedbackViewModel: FeedbackInboxViewModel

    init(hasData: Bool) {
      let studentID = StudentDemoSeed.studentID
      let plan = StudentDemoSeed.makePlanView()
      self.hasData = hasData
      self.plans = InMemoryStudentPlanRepository(
        store: StudentRootDemoPlanStore(studentID: studentID, plan: plan)
      )
      self.logs = InMemoryStudentTrainingLogRepository(
        seed: hasData ? StudentDemoSeed.makeHistoricalLogs(studentID: studentID) : []
      )
      self.e1rm = InMemoryE1RMRepository(
        seedPoints: hasData ? StudentDemoSeed.makeE1RMHistory(studentID: studentID) : []
      )
      self.onboarding = InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
      self.feedbackViewModel = FeedbackInboxViewModel(
        repository: InMemoryStudentFeedbackRepository(
          seed: hasData ? StudentDemoSeed.makeFeedback(studentID: studentID) : []
        )
      )
    }

    var body: some View {
      TrainingHistoryView(
        studentID: StudentDemoSeed.studentID,
        plans: plans,
        logs: logs,
        e1rm: e1rm,
        onboarding: onboarding,
        feedbackViewModel: feedbackViewModel
      )
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private struct MyProfileV3Preview: View {
    private let plans: InMemoryStudentPlanRepository
    private let logs: InMemoryStudentTrainingLogRepository
    private let e1rm: InMemoryE1RMRepository
    private let onboarding: InMemoryOnboardingRepository
    private let readiness: InMemoryReadinessRepository

    init() {
      let studentID = StudentDemoSeed.studentID
      self.plans = InMemoryStudentPlanRepository(
        store: StudentRootDemoPlanStore(
          studentID: studentID,
          plan: StudentDemoSeed.makePlanView()
        )
      )
      self.logs = InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
      )
      self.e1rm = InMemoryE1RMRepository(
        seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: studentID)
      )
      self.onboarding = InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
      self.readiness = InMemoryReadinessRepository(
        seed: StudentDemoSeed.makeReadinessHistory(studentID: studentID)
      )
    }

    var body: some View {
      MyProfileView(
        studentID: StudentDemoSeed.studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding,
        readiness: readiness,
        onLogout: {},
        account: InMemoryAccountRepository(),
        logs: logs,
        restTimerSettings: PreviewRestTimerSettingsStore()
      )
    }
  }

  private struct PreviewRestTimerSettingsStore: StudentRestTimerSettingsStoring {
    func preference(for studentID: UUID) -> StudentRestTimerPreference {
      .automatic
    }

    func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID) {}

    func hasAcknowledgedExplanation(for studentID: UUID) -> Bool {
      false
    }

    func markExplanationAcknowledged(for studentID: UUID) {}
  }

  #Preview("W2c · 成长有数据 · Dark") {
    GrowthV3Preview(hasData: true)
      .preferredColorScheme(.dark)
  }

  #Preview("W2c · 成长有数据 · Light") {
    GrowthV3Preview(hasData: true)
      .preferredColorScheme(.light)
  }

  #Preview("W2c · 成长空态 · Dark") {
    GrowthV3Preview(hasData: false)
      .preferredColorScheme(.dark)
  }

  #Preview("W2c · 成长空态 · Light") {
    GrowthV3Preview(hasData: false)
      .preferredColorScheme(.light)
  }

  #Preview("W2c · 我的 · Dark") {
    MyProfileV3Preview()
      .preferredColorScheme(.dark)
  }

  #Preview("W2c · 我的 · Light") {
    MyProfileV3Preview()
      .preferredColorScheme(.light)
  }
#endif
