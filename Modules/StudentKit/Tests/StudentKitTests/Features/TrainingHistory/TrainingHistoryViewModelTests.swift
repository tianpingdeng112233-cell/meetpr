import CoreModels
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

/// spec 047 §2: solo history fetches scope=all (the seeded rows are adhoc —
/// a plan-scoped fetch would drop them), never asks for a plan (throwing
/// plans repo proves it), and groups 日即会话 by calendar month.
@MainActor
@Test func trainingHistorySoloGroupsAdhocLogsByMonth() async throws {
  let studentID = StudentDemoSeed.studentID
  let squat = Exercise(
    id: UUID(), name: "低杠位深蹲", nameEn: "Low-Bar Squat", exerciseType: .mainLift,
    mainLiftFamily: .squat, isCompetitionLift: true, muscleGroups: [.quad],
    equipment: [.barbell], createdAt: Date(timeIntervalSince1970: 0))
  let now = try Date("2026-07-04T10:00:00Z", strategy: .iso8601)
  func adhocLog(daysAgo: Int, setIndex: Int) -> StudentSetLog {
    let loggedAt = now.addingTimeInterval(Double(-daysAgo) * 86_400)
    return StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: nil, exerciseID: squat.id,
      loggedDate: SoloSessionViewModel.dayString(loggedAt, calendar: .current),
      adhoc: true, setIndex: setIndex, loggedAt: loggedAt,
      weightKg: 140, reps: 5, rpe: 8, completed: true)
  }
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { URLError(.badServerResponse) },
    logs: InMemoryStudentTrainingLogRepository(
      seed: [adhocLog(daysAgo: 1, setIndex: 1), adhocLog(daysAgo: 40, setIndex: 1)]
    ),
    mode: .selfTrain,
    catalog: [squat],
    now: { now }
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(let weeks, let fetched) = viewModel.state else {
    Issue.record("Expected loaded state, got \(viewModel.state)")
    return
  }
  #expect(weeks.isEmpty)
  #expect(fetched.count == 2)
  #expect(viewModel.soloMonths.count == 2)
  let newest = try #require(viewModel.soloMonths.first?.days.first)
  #expect(newest.exerciseNames == ["低杠位深蹲"])
  #expect(newest.setCount == 1)
  // 本月次数 (stats row): only the day inside the current month counts.
  #expect(viewModel.currentMonthSessionCount == 1)
}

@MainActor
@Test func soloMonthTitlesReadAsChineseYearMonth() {
  #expect(TrainingHistoryViewModel.monthTitle(for: "2026-07") == "2026 年 7 月")
  #expect(TrainingHistoryViewModel.monthTitle(for: "junk") == "junk")
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
