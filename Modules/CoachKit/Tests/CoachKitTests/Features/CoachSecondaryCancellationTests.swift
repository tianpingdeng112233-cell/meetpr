import CoreModels
import Foundation
import Networking
import Testing

@testable import CoachKit

@MainActor
struct CoachSecondaryCancellationTests {
  @Test(arguments: [true, false])
  func detailCatalogCancellationKeepsServerNames(urlCancellation: Bool) async throws {
    let summary = CoachStudentFeatureFixtures.summary()
    let plan = CoachStudentFeatureFixtures.plan()
    let exercise = CoachStudentFeatureFixtures.exercise().exercise
    let day = try #require(plan.days.first)
    let log = CoachSetLogDTO(
      id: UUID(), studentID: summary.id, planExerciseID: nil, planDayID: day.id,
      adhoc: true, exerciseID: exercise.id, setIndex: 0, weightKg: 100, reps: 5,
      completed: true, loggedAt: day.date)
    let planning = StubCoachPlanRepository(students: [summary])
    await planning.setCatalog([exercise], logs: [log])
    let model = StudentDetailViewModel(
      summary: summary, plans: StubStudentPlanRepository(plans: [summary.id: plan]),
      trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository(),
      planning: planning, now: { day.date })
    await model.refresh()
    let days = model.executionDays
    #expect(days.first?.exerciseCatalog[exercise.id] == exercise)
    await planning.setCatalogError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.executionDays.first?.exerciseCatalog[exercise.id] == exercise)
  }

  @Test(arguments: [true, false])
  func videoQueuePlanCancellationKeepsExerciseNames(urlCancellation: Bool) async throws {
    let summary = CoachStudentFeatureFixtures.summary()
    let plan = CoachStudentFeatureFixtures.plan()
    let exercise = try #require(plan.days.flatMap(\.exercises).first)
    let plans = StubStudentPlanRepository(plans: [summary.id: plan])
    let repository = AggregatingCoachVideoQueueRepository(
      roster: StubCoachPlanRepository(students: [summary]),
      videos: StubCoachStudentVideoRepository(videos: [
        VideoInboxFixtures.video(planExerciseID: exercise.id, createdAt: Date())
      ]), feedback: StubFeedbackRepository(), plans: plans)
    let model = CoachVideoQueueViewModel(repository: repository)
    await model.refresh()
    #expect(model.items.first?.exerciseName == exercise.exercise.name)
    await plans.setFetchError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.items.first?.exerciseName == exercise.exercise.name)
  }

  @Test(arguments: [true, false])
  func workspaceChildCancellationKeepsRows(urlCancellation: Bool) async throws {
    let summary = CoachStudentFeatureFixtures.summary()
    let plans = StubStudentPlanRepository(plans: [:])
    let model = PlanningWorkspaceViewModel(
      repository: StubCoachPlanRepository(students: [summary]), studentPlans: plans,
      draftStore: try DraftStore.inMemory())
    await model.refresh()
    let rows = model.needsPlanningRows
    #expect(!rows.isEmpty)
    await plans.setFetchError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.needsPlanningRows == rows)
  }

  @Test(arguments: [true, false])
  func detailSecondaryCancellationKeepsSections(urlCancellation: Bool) async {
    let summary = CoachStudentFeatureFixtures.summary()
    let videos = StubCoachStudentVideoRepository(videos: [
      VideoInboxFixtures.video(planExerciseID: UUID(), createdAt: Date())
    ])
    let readiness = StubReadinessRepository()
    let profiles = StubProfileReader(
      profile: OnboardingProfile(
        userId: summary.id, squat1RMKg: 180, createdAt: Date(), updatedAt: Date()))
    let model = StudentDetailViewModel(
      summary: summary, plans: StubStudentPlanRepository(plans: [:]),
      trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository(),
      videos: videos, readiness: readiness, profiles: profiles)
    await model.refresh()
    let previousVideos = model.videos
    let previousReadiness = model.todayReadiness
    let previousProfile = model.profileState
    let error: any Error = urlCancellation ? URLError(.cancelled) : CancellationError()
    await videos.setCancellationError(error)
    await readiness.setCancellationError(error)
    await profiles.setCancellationError(error)
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.videos == previousVideos)
    #expect(!model.videosUnavailable)
    #expect(model.todayReadiness == previousReadiness)
    #expect(model.profileState == previousProfile)
  }

  @Test(arguments: [true, false])
  func rosterChildCancellationKeepsCompleteRows(urlCancellation: Bool) async {
    let summary = CoachStudentFeatureFixtures.summary()
    let plans = StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()])
    let model = StudentRosterViewModel(
      students: StubCoachPlanRepository(students: [summary]), plans: plans,
      trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository())
    await model.refresh()
    let rows = model.rows
    #expect(rows.first?.trainingDays.isEmpty == false)
    await plans.setFetchError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.rows == rows)
  }
}

extension StubCoachStudentVideoRepository {
  func setCancellationError(_ error: Error?) { fetchError = error }
}
extension StubReadinessRepository {
  func setCancellationError(_ error: Error?) { fetchError = error }
}
extension StubProfileReader {
  func setCancellationError(_ error: Error?) { self.error = error }
}

extension StubCoachPlanRepository {
  func setCatalog(_ exercises: [Exercise], logs: [CoachSetLogDTO]) {
    catalog = exercises
    coachLogs = logs
  }
  func setCatalogError(_ error: Error?) { catalogError = error }
}
