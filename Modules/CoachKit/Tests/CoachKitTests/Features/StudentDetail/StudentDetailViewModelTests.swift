import CoreModels
import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailDefinesFiveSectionsInSpecOrder() {
  #expect(StudentDetailSection.allCases.map(\.title) == ["概览", "执行", "视频", "成长", "反馈"])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailLoadsExecutionAndFeedbackSummaries() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let plan = CoachStudentFeatureFixtures.plan()
  let log = CoachStudentFeatureFixtures.log()
  let feedback = CoachStudentFeatureFixtures.feedback()
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: plan]),
    trainingLogs: StubTrainingLogRepository(logs: [log]),
    feedback: StubFeedbackRepository(feedback: [feedback]),
    now: { CoachStudentFeatureFixtures.startDate.addingTimeInterval(3 * 86_400) }
  )

  await viewModel.refresh()

  #expect(viewModel.executionDays.count == 7)
  #expect(viewModel.overview.plannedTrainingDays == 1)
  #expect(viewModel.overview.completedTrainingDays == 1)
  #expect(viewModel.feedbackItems.first?.id == feedback.id)
  #expect(viewModel.allPlanExercises.map(\.id) == [CoachStudentFeatureFixtures.planExerciseID])

  viewModel.select(.feedback)
  #expect(viewModel.selectedSection == .feedback)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailBucketsUTCPlusEightEarlyMorningLogIntoLocalPlanDay() throws {
  var utc = Calendar(identifier: .gregorian)
  utc.timeZone = TimeZone(secondsFromGMT: 0)!
  var utcPlusEight = Calendar(identifier: .gregorian)
  utcPlusEight.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!

  let planDate = try #require(
    date(utc, DateComponents(year: 2026, month: 2, day: 1, hour: 0, minute: 0))
  )
  let earlyMorningLogDate = try #require(
    date(utcPlusEight, DateComponents(year: 2026, month: 2, day: 1, hour: 0, minute: 30))
  )
  let planDay = StudentPlanDay(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000000777")!,
    date: planDate,
    exercises: [CoachStudentFeatureFixtures.exercise()]
  )
  let plan = StudentPlanView(
    cycleID: UUID(uuidString: "02900000-0000-0000-0000-000000000778")!,
    weekIndex: 1,
    startDate: planDate,
    days: [planDay]
  )
  let days = StudentDetailViewModel.makeExecutionDays(
    plan: plan,
    logs: [CoachStudentFeatureFixtures.log(loggedAt: earlyMorningLogDate)],
    now: planDate,
    calendar: utcPlusEight
  )

  #expect(days[0].planDay?.id == planDay.id)
  #expect(days[0].logs.count == 1)
  #expect(days[0].logs[0].loggedAt == earlyMorningLogDate)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailAppendPostedFeedbackRefreshesLatestOverview() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let older = CoachStudentFeatureFixtures.feedback(
    postedAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(86_400)
  )
  let newer = CoachStudentFeatureFixtures.feedback(
    postedAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(4 * 86_400)
  )
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository(feedback: [older])
  )

  await viewModel.refresh()
  viewModel.appendPostedFeedback(newer)

  #expect(viewModel.feedbackItems.first?.id == newer.id)
  #expect(viewModel.overview.latestFeedback?.id == newer.id)
}

private func date(_ calendar: Calendar, _ dateComponents: DateComponents) -> Date? {
  var components = dateComponents
  components.calendar = calendar
  components.timeZone = calendar.timeZone
  return calendar.date(from: components)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailLoadsVideoWallAndTodayReadiness() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let now = CoachStudentFeatureFixtures.startDate.addingTimeInterval(3 * 86_400)
  let videos = (0..<4).map { offset in
    CoachStudentFeatureFixtures.video(
      id: UUID(uuidString: String(format: "02900000-0000-0000-0000-%012d", 3_001 + offset))!,
      createdAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(
        Double(offset) * 86_400)
    )
  }
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(
    checkinDate: CoachStudentFormatting.localDayString(now)
  )
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository(),
    videos: StubCoachStudentVideoRepository(videos: videos),
    readiness: StubReadinessRepository(checkins: [checkin]),
    now: { now }
  )

  await viewModel.refresh()

  #expect(viewModel.state == .loaded)
  // Wall is newest-first; the overview card shows the newest three.
  #expect(viewModel.videos.map(\.id) == videos.reversed().map(\.id))
  #expect(viewModel.recentVideos.count == 3)
  #expect(viewModel.recentVideos.map(\.id) == videos.reversed().prefix(3).map(\.id))
  #expect(viewModel.videosUnavailable == false)
  #expect(viewModel.todayReadiness == .loaded(checkin))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailVideoWallFailureDegradesInPlaceWithoutBlankingDetail() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository(),
    videos: StubCoachStudentVideoRepository(fetchError: CoachFeatureTestError()),
    readiness: StubReadinessRepository()
  )

  await viewModel.refresh()

  #expect(viewModel.state == .loaded)
  #expect(viewModel.videosUnavailable)
  #expect(viewModel.videos.isEmpty)
  #expect(viewModel.recentVideos.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailReadinessDistinguishesNotFiledFromFetchFailure() async {
  let summary = CoachStudentFeatureFixtures.summary()

  func makeViewModel(readiness: StubReadinessRepository) -> StudentDetailViewModel {
    StudentDetailViewModel(
      summary: summary,
      plans: StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()]),
      trainingLogs: StubTrainingLogRepository(logs: []),
      feedback: StubFeedbackRepository(),
      videos: StubCoachStudentVideoRepository(),
      readiness: readiness
    )
  }

  let notFiled = makeViewModel(readiness: StubReadinessRepository())
  await notFiled.refresh()
  #expect(notFiled.todayReadiness == .notFiled)

  let unavailable = makeViewModel(
    readiness: StubReadinessRepository(fetchError: CoachFeatureTestError())
  )
  await unavailable.refresh()
  #expect(unavailable.todayReadiness == .unavailable)
}
