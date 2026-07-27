import CatalogKit
import CoachKit
import CoreModels
import RepositoryContracts
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {
  @Environment(Session.self) private var session
  private let coachPlans: any PlanRepository
  private let coachInviteCodes: any InviteCodeRepository
  private let coachBindQueue: any CoachBindQueueRepository
  private let coachDashboard: any CoachDashboardRepository
  private let coachStudentProfiles: any OnboardingProfileReading
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  /// Offline-parking wrapper for solo (adhoc) writes, built once around
  /// studentLogs (spec 045); coached flows keep the direct path.
  private let soloLogs: QueuedTrainingLogRepository
  private let studentSessionReviews: any SessionReviewRepository
  private let studentAccount: any AccountRepository
  /// Decoding 1211 catalog entries is not free — load once per process.
  private static let soloCatalog = ExerciseCatalog.loadBundled()
  private let studentFeedback: any StudentFeedbackRepository
  private let studentE1RM: any E1RMRepository
  private let studentReadiness: any ReadinessRepository
  private let studentVideoUploads: VideoUploadServices?
  private let studentBind: any BindRepository
  private let studentOnboarding: any OnboardingRepository
  private let pendingBindStore: any PendingBindCodeStoring
  private let onboardingDraftStore = LocalOnboardingDraftStore()
  private let coachStudentVideos: any CoachStudentVideoRepository
  private let coachVideoQueue: (any CoachVideoQueueRepository)?
  private let coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)?
  private let draftStore: DraftStore
  private let appNavigation: AppNavigationModel

  public init(
    coachPlans: any PlanRepository = InMemoryPlanRepository.preview(),
    coachInviteCodes: (any InviteCodeRepository)? = nil,
    coachBindQueue: (any CoachBindQueueRepository)? = nil,
    coachDashboard: (any CoachDashboardRepository)? = nil,
    coachStudentProfiles: (any OnboardingProfileReading)? = nil,
    studentPlans: (any StudentPlanRepository)? = nil,
    studentLogs: (any StudentTrainingLogRepository)? = nil,
    studentFeedback: (any StudentFeedbackRepository)? = nil,
    studentE1RM: (any E1RMRepository)? = nil,
    studentReadiness: (any ReadinessRepository)? = nil,
    studentVideoUploads: VideoUploadServices? = nil,
    studentBind: (any BindRepository)? = nil,
    studentOnboarding: (any OnboardingRepository)? = nil,
    studentSessionReviews: (any SessionReviewRepository)? = nil,
    studentAccount: (any AccountRepository)? = nil,
    pendingBindStore: any PendingBindCodeStoring = UserDefaultsPendingBindCodeStore(),
    coachStudentVideos: (any CoachStudentVideoRepository)? = nil,
    coachVideoQueue: (any CoachVideoQueueRepository)? = nil,
    coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)? = nil,
    appNavigation: AppNavigationModel = AppNavigationModel(),
    draftStore: DraftStore = DraftStore.shared
  ) {
    self.coachPlans = coachPlans
    self.coachInviteCodes = coachInviteCodes ?? RootViewDemoDefaults.inviteCodes()
    self.studentPlans = studentPlans ?? RootViewDemoDefaults.plans()
    let resolvedLogs = studentLogs ?? RootViewDemoDefaults.logs()
    self.studentLogs = resolvedLogs
    self.soloLogs = QueuedTrainingLogRepository(
      upstream: resolvedLogs, store: PendingSetLogStore())
    self.studentSessionReviews = studentSessionReviews ?? InMemorySessionReviewRepository()
    self.studentAccount = studentAccount ?? InMemoryAccountRepository()
    self.studentFeedback = studentFeedback ?? RootViewDemoDefaults.feedback()
    self.studentE1RM = studentE1RM ?? RootViewDemoDefaults.e1rm()
    self.studentReadiness = studentReadiness ?? RootViewDemoDefaults.readiness()
    self.studentVideoUploads = studentVideoUploads
    self.studentBind = studentBind ?? RootViewDemoDefaults.bind()
    self.studentOnboarding = studentOnboarding ?? RootViewDemoDefaults.onboarding()
    self.coachBindQueue =
      coachBindQueue
      ?? InMemoryCoachBindQueueRepository()
    self.coachDashboard =
      coachDashboard
      ?? InMemoryCoachDashboardRepository(
        signals: CoachDemoSeed.dashboardSignals(),
        dailyDigestBody: CoachDemoSeed.dailyDigestBody
      )
    self.coachStudentProfiles =
      coachStudentProfiles ?? RootViewDemoDefaults.coachStudentProfiles()
    self.pendingBindStore = pendingBindStore
    self.coachStudentVideos = coachStudentVideos ?? InMemoryCoachStudentVideoRepository()
    self.coachVideoQueue = coachVideoQueue
    self.coachFamilyMapProvider = coachFamilyMapProvider
    self.appNavigation = appNavigation
    self.draftStore = draftStore
  }

  public var body: some View {
    switch session.state {
    case .anonymous:
      AuthFlowView()
    case .authenticating:
      VStack(spacing: 12) {
        ProgressView()
        Text("正在验证会话…")
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    case .authenticated(let user):
      switch user.role {
      case .coach:
        CoachRootView(
          repository: coachPlans,
          studentPlans: studentPlans,
          studentLogs: studentLogs,
          feedback: studentFeedback,
          inviteCodes: coachInviteCodes,
          studentVideos: coachStudentVideos,
          readiness: studentReadiness,
          familyMapProvider: coachFamilyMapProvider,
          bindQueue: coachBindQueue,
          studentProfiles: coachStudentProfiles,
          videoQueue: coachVideoQueue,
          dashboard: coachDashboard,
          tabSelection: appNavigation.coachTabSelection,
          onLogout: {
            await session.logout()
          },
          draftStore: draftStore
        )
      case .coachedStudent:
        // BindGate wraps coached students only (spec 031 D4); the wizard
        // slot + completion-probe closures are 032's real implementations.
        bindGatedStudentRoot(for: user)
      case .selfTrainStudent:
        // Self-train students never bind (backend requireRole gate) and
        // skip the BindGate entirely (spec 031 D4). Their gate is the
        // 2-screen light onboarding instead (spec 046).
        SoloOnboardingGateView(studentId: user.id, onboarding: studentOnboarding) {
          studentRoot(for: user)
        }
      }
    }
  }

  private func bindGatedStudentRoot(for user: User) -> some View {
    let onboarding = studentOnboarding
    let studentId = user.id
    return BindGateView(
      studentId: studentId,
      bind: studentBind,
      stash: pendingBindStore,
      isOnboardingComplete: {
        // Fetch failure reads as "incomplete" (`try?` flattens the error and
        // the 404 into nil): worst case is one extra trip through the wizard
        // resume, which is harmless (spec 032 contract).
        guard let profile = try? await onboarding.fetchProfile(studentId: studentId) else {
          return false
        }
        return profile.isCompleted
      },
      onboardingProfile: {
        try? await onboarding.fetchProfile(studentId: studentId)
      },
      // Pre-bind pages live outside the 5 tabs — without this the account
      // has no way back to the login screen.
      onLogout: {
        await session.logout()
      },
      onboardingFlow: { _, onCompleted in
        OnboardingWizardFlow(
          studentId: studentId,
          repo: onboarding,
          draftStore: onboardingDraftStore,
          bind: studentBind,
          stash: pendingBindStore,
          onCompleted: onCompleted
        )
      },
      content: {
        studentRoot(for: user)
      }
    )
  }

  private func studentRoot(for user: User) -> some View {
    let isSolo = user.role == .selfTrainStudent
    let soloLogs = self.soloLogs
    let logsForUser: any StudentTrainingLogRepository = isSolo ? soloLogs : studentLogs
    let trainingMode: TrainingMode = isSolo ? .selfTrain : .coached
    // Both modes get the bundled catalog (spec 048): CSV export resolves
    // names through it, and coached chart buckets treat the extra ids as a
    // harmless union (no e1RM points live on unplanned catalog ids).
    let catalog: [Exercise] = Self.soloCatalog
    let pendingCount: (@Sendable (UUID) async -> Int)?
    if isSolo {
      pendingCount = { studentID in await soloLogs.pendingCount(studentID: studentID) }
    } else {
      pendingCount = nil
    }
    return StudentRootView(
      studentID: user.id,
      canShiftPlanDays: user.role == .coachedStudent,
      plans: studentPlans,
      logs: logsForUser,
      feedback: studentFeedback,
      e1rm: studentE1RM,
      readiness: studentReadiness,
      videoUploads: studentVideoUploads,
      onboarding: studentOnboarding,
      onLogout: {
        await session.logout()
      },
      trainingMode: trainingMode,
      soloCatalog: catalog,
      pendingSetLogCount: pendingCount,
      sessionReviews: studentSessionReviews,
      account: studentAccount
    )
  }
}

/// Demo/preview fallbacks for RootView's injection points. An accepted bond
/// plus a completed profile keep the existing student demo flow untouched —
/// the BindGate falls straight through to the 5 tabs (spec 031 D10).
@available(iOS 17.0, macOS 14.0, *)
private enum RootViewDemoDefaults {
  static func inviteCodes() -> any InviteCodeRepository {
    InMemoryInviteCodeRepository(
      coachId: StudentDemoSeed.coachID,
      seed: InMemoryInviteCodeRepository.demoSeed(coachId: StudentDemoSeed.coachID)
    )
  }

  static func plans() -> any StudentPlanRepository {
    let plan = StudentDemoSeed.makePlanView()
    let store = InMemoryPlanStore()
    Task {
      await store.savePublishedProjection(plan, forStudent: StudentDemoSeed.studentID)
    }
    return InMemoryStudentPlanRepository(store: store)
  }

  static func logs() -> any StudentTrainingLogRepository {
    InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
    )
  }

  static func feedback() -> any StudentFeedbackRepository {
    InMemoryStudentFeedbackRepository(
      seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
    )
  }

  static func e1rm() -> any E1RMRepository {
    InMemoryE1RMRepository(
      seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
      seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
    )
  }

  static func readiness() -> any ReadinessRepository {
    InMemoryReadinessRepository(
      seed: StudentDemoSeed.makeReadinessHistory(studentID: StudentDemoSeed.studentID)
    )
  }

  static func bind() -> any BindRepository {
    InMemoryBindRepository(
      studentId: StudentDemoSeed.studentID,
      seed: StudentDemoSeed.makeAcceptedBindRequest(studentID: StudentDemoSeed.studentID)
    )
  }

  static func onboarding() -> any OnboardingRepository {
    InMemoryOnboardingRepository(
      studentId: StudentDemoSeed.studentID,
      seed: StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
    )
  }

  static func coachStudentProfiles() -> any OnboardingProfileReading {
    InMemoryCoachStudentProfileReader(
      profiles: [StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)]
    )
  }
}
