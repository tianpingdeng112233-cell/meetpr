import Foundation
import Testing

@testable import StudentKit

/// Regression for the TestFlight "加载失败 / cancelled" bug: when SwiftUI
/// cancels the first-load `.task` during the post-login settling window, the
/// thrown URLError.cancelled / CancellationError must NOT become a visible
/// error. The view model returns to `.idle` so the rebuilt `.task` retries.
@MainActor
@Test func trainingHistoryViewModelIgnoresURLCancellation() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { URLError(.cancelled) },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .idle)
}

@MainActor
@Test func trainingHistoryViewModelIgnoresCancellationError() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { CancellationError() },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .idle)
}

@MainActor
@Test func trainingHistoryViewModelSurfacesRealError() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { URLError(.timedOut) },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  guard case .error = viewModel.state else {
    Issue.record("Expected a non-cancellation error to surface as .error")
    return
  }
}

/// spec 051 §1 回显: a saved one-liner shows up keyed to its day after load.
@MainActor
@Test func trainingHistoryViewModelIndexesReviewsByDay() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let reviews = InMemorySessionReviewRepository()
  let viewModel = TrainingHistoryViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
    ),
    reviews: reviews
  )

  await viewModel.load(studentID: studentID)
  guard case .loaded(let weeks, _) = viewModel.state, let day = weeks.first?.days.first else {
    Issue.record("Expected loaded state with at least one day")
    return
  }

  let key = SoloSessionViewModel.dayString(day.date, calendar: .current)
  _ = try await reviews.submitReview(
    studentID: studentID, reviewDate: key, feeling: "推得顺", sessionRPE: 8)
  await viewModel.load(studentID: studentID)

  #expect(viewModel.reviewsByDay[key]?.feeling == "推得顺")
  #expect(viewModel.reviewsByDay[key]?.sessionRPE == 8)
}

@MainActor
@Test func trainingHistoryViewModelGroupsCycleDaysIntoWeeks() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TrainingHistoryViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
    )
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(let weeks, let logs) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(weeks.count == 1)
  #expect(weeks[0].days.count == 7)
  #expect(!logs.isEmpty)
}
