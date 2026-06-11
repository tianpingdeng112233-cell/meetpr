import CoreModels
import Testing

@testable import StudentKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentRootViewInitializes() {
  _ = StudentRootView()
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentRootViewInitializesWithInjectedRepositories() {
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
  _ = StudentRootView(
    studentID: StudentDemoSeed.studentID,
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    feedback: InMemoryStudentFeedbackRepository()
  )
}
