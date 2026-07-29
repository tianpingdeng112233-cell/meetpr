import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite("Set number surfaces")
struct SetNumberSurfaceTests {
  @Test("feedback detail renders source index zero as set one")
  func feedbackDetailRendersSourceIndexZeroAsSetOne() throws {
    let video = CoachFeedbackVideo(
      id: UUID(),
      exerciseName: "深蹲",
      setIndex: 0
    )
    let feedback = CoachFeedback(
      id: UUID(),
      coachID: UUID(),
      studentID: UUID(),
      videoID: video.id,
      video: video,
      text: "保持节奏",
      postedAt: Date(timeIntervalSince1970: 1_777_248_000)
    )

    let inspected = try FeedbackDetailView(item: feedback).inspect()

    #expect(try inspected.find(text: "深蹲 · 第1组").string() == "深蹲 · 第1组")
  }

  @Test("v3 set row renders source index zero as set one")
  func v3SetRowRendersSourceIndexZeroAsSetOne() throws {
    let fixture = makeSurfaceFixture()
    let inspected = try SetRow(
      index: SetDisplayNumber.number(for: fixture.draft),
      weight: 100,
      reps: 5,
      rpe: 8,
      status: .pending,
      videoState: .none
    ).inspect()

    #expect(try inspected.find(text: "1").string() == "1")
  }

  @Test("today workout table offset path renders source index zero as set one")
  func todayWorkoutTableRendersSourceIndexZeroAsSetOne() async throws {
    let fixture = try await makeTodayWorkoutFixture()

    let setNumber = try fixture.view.inspect().find(
      viewWithAccessibilityIdentifier:
        "todayWorkout.set.\(fixture.firstSetID.uuidString).number"
    )

    #expect(try setNumber.text().string() == "1")
  }

  @Test("today workout hero stored-index path renders source index zero as set one")
  func todayWorkoutHeroRendersSourceIndexZeroAsSetOne() async throws {
    let fixture = try await makeTodayWorkoutFixture()

    let position = try fixture.view.inspect().find(
      viewWithAccessibilityIdentifier: "todayWorkout.activeSet.position"
    )

    #expect(try position.text().string().contains("第 1 /"))
  }

  @Test("set entry sheet renders a source-zero draft as set one")
  func setEntrySheetRendersSourceZeroDraftAsSetOne() throws {
    let fixture = makeSurfaceFixture()
    let viewModel = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
      logs: InMemoryStudentTrainingLogRepository()
    )
    let inspected = try SetEntrySheet(
      rowIndex: 0,
      draft: fixture.draft,
      setNumber: SetDisplayNumber.number(for: fixture.draft),
      viewModel: viewModel
    ).inspect()

    #expect(try inspected.find(text: "深蹲 · 第 1 组").string() == "深蹲 · 第 1 组")
  }

  @Test("day detail renders source index zero as set one")
  func dayDetailRendersSourceIndexZeroAsSetOne() throws {
    let fixture = makeSurfaceFixture()
    let inspected = try DayDetailView(day: fixture.day, logs: []).inspect()

    #expect(try inspected.find(text: "第 1 组").string() == "第 1 组")
  }

  @Test("history entries render source index zero as set one")
  func historyEntriesRenderSourceIndexZeroAsSetOne() throws {
    let fixture = makeSurfaceFixture()
    let inspected = try HistoryEntriesView(
      weeks: [.init(id: 1, days: [fixture.day])],
      logs: [],
      selectedExerciseName: .constant(nil)
    ).inspect()

    #expect(try inspected.find(text: "第 1 组").string() == "第 1 组")
  }
}

@MainActor
private struct SurfaceFixture {
  let day: StudentPlanDay
  let exercise: StudentPlanExercise
  let draft: TodayWorkoutViewModel.SetRowDraft
}

@MainActor
private func makeSurfaceFixture() -> SurfaceFixture {
  let timestamp = Date(timeIntervalSince1970: 1_777_248_000)
  let prescribed = PrescribedSet(
    id: UUID(),
    setIndex: 0,
    weightKg: 100,
    reps: 5,
    rpe: 8
  )
  let exercise = StudentPlanExercise(
    id: UUID(),
    exercise: Exercise(
      id: UUID(),
      name: "深蹲",
      exerciseType: .mainLift,
      mainLiftFamily: .squat,
      isCompetitionLift: true,
      muscleGroups: [.quad],
      equipment: [.barbell],
      movementPattern: [.squat],
      createdAt: timestamp
    ),
    sequenceIndex: 0,
    prescribedSets: [prescribed]
  )
  let day = StudentPlanDay(
    id: UUID(),
    date: timestamp,
    exercises: [exercise]
  )
  let draft = TodayWorkoutViewModel.SetRowDraft(
    id: prescribed.id,
    planExerciseID: exercise.id,
    exerciseID: exercise.exercise.id,
    exerciseName: exercise.exercise.name,
    isAccessory: false,
    isMainLift: true,
    prescribed: prescribed
  )
  return SurfaceFixture(day: day, exercise: exercise, draft: draft)
}

@MainActor
private func makeTodayWorkoutFixture() async throws -> (
  view: TodayWorkoutView,
  firstSetID: UUID
) {
  let studentID = StudentDemoSeed.studentID
  // One frozen clock for both the seed and the filter: two separate Date() calls can straddle
  // UTC midnight and leave the filter with no matching training day.
  let now = Date()
  let plan = StudentDemoSeed.makePlanView(today: now)
  let day = try #require(plan.days.first { !$0.exercises.isEmpty && $0.date >= now })
  let firstSetID = try #require(day.exercises.first?.prescribedSets.first?.id)
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: repository,
    logs: logs
  )
  await viewModel.load(date: day.date, studentID: studentID)
  return (
    TodayWorkoutView(
      studentID: studentID,
      date: day.date,
      plans: repository,
      logs: logs,
      preloadedViewModel: viewModel,
      started: true
    ),
    firstSetID
  )
}
