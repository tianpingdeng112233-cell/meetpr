import CoachKit
import CoreModels
import RepositoryContracts
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {
  @Environment(Session.self) private var session
  private let coachPlans: any PlanRepository
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let studentFeedback: any StudentFeedbackRepository
  private let studentE1RM: any E1RMRepository
  private let draftStore: DraftStore

  public init(
    coachPlans: any PlanRepository = InMemoryPlanRepository.preview(),
    studentPlans: (any StudentPlanRepository)? = nil,
    studentLogs: (any StudentTrainingLogRepository)? = nil,
    studentFeedback: (any StudentFeedbackRepository)? = nil,
    studentE1RM: (any E1RMRepository)? = nil,
    draftStore: DraftStore = DraftStore.shared
  ) {
    let plan = StudentDemoSeed.makePlanView()
    let store = InMemoryPlanStore()
    Task {
      await store.savePublishedProjection(plan, forStudent: StudentDemoSeed.studentID)
    }
    self.coachPlans = coachPlans
    self.studentPlans = studentPlans ?? InMemoryStudentPlanRepository(store: store)
    self.studentLogs =
      studentLogs
      ?? InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
      )
    self.studentFeedback =
      studentFeedback
      ?? InMemoryStudentFeedbackRepository(
        seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
      )
    self.studentE1RM =
      studentE1RM
      ?? InMemoryE1RMRepository(
        seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
        seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
      )
    self.draftStore = draftStore
  }

  public var body: some View {
    switch session.state {
    case .anonymous, .authenticating:
      AuthFlowView()
    case .authenticated(let user):
      switch user.role {
      case .coach:
        CoachRootView(
          repository: coachPlans,
          studentPlans: studentPlans,
          studentLogs: studentLogs,
          feedback: studentFeedback,
          onLogout: {
            await session.logout()
          },
          draftStore: draftStore
        )
      case .coachedStudent, .selfTrainStudent:
        StudentRootView(
          studentID: user.id,
          plans: studentPlans,
          logs: studentLogs,
          feedback: studentFeedback,
          e1rm: studentE1RM
        )
      }
    }
  }
}
