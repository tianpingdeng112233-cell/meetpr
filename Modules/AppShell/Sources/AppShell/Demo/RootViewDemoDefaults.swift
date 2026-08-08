import CoachKit
import RepositoryContracts
import StudentKit

/// Demo/preview fallbacks for RootView's injection points. An accepted bond
/// plus a completed profile keep the existing student demo flow untouched —
/// the BindGate falls straight through to the 5 tabs (spec 031 D10).
@available(iOS 17.0, macOS 14.0, *)
enum RootViewDemoDefaults {
  private static let trainingLogs = InMemoryStudentTrainingLogRepository(
    seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
  )

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
    trainingLogs
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
