import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite("Today workout set-ref entry layout")
struct TodayWorkoutSetRefEntryLayoutTests {
  @Test("in-progress hero owns the only ask-coach entry")
  func inProgressHeroOwnsAskCoachEntry() async throws {
    let view = try await makeView(completedSetIndexes: [1])

    #expect(askCoachEntryCount(in: view) == 1)
  }

  @Test("completed section owns the only ask-coach entry")
  func completedSectionOwnsAskCoachEntry() async throws {
    let view = try await makeView(completedSetIndexes: [0, 1])

    #expect(askCoachEntryCount(in: view) == 1)
  }

  @Test("v3 set row stays free of a per-row ask-coach entry")
  func v3SetRowHasNoAskCoachEntry() throws {
    let inspected = try SetRow(
      index: 1,
      weight: 100,
      reps: 5,
      rpe: 8,
      status: .done,
      videoState: .none
    ).inspect()

    #expect(
      inspected.findAll {
        try $0.accessibilityIdentifier() == "todayWorkout.askCoach"
      }.isEmpty
    )
  }

  private func askCoachEntryCount(in view: TodayWorkoutView) -> Int {
    let inspected = try? view.inspect()
    return inspected?.findAll {
      try $0.accessibilityIdentifier() == "todayWorkout.askCoach"
    }.count ?? 0
  }

  // swiftlint:disable:next function_body_length
  private func makeView(completedSetIndexes: Set<Int>) async throws -> TodayWorkoutView {
    let calendar = Calendar.current
    let planDayDate =
      calendar.date(
        bySettingHour: 12,
        minute: 0,
        second: 0,
        of: WorkoutDatePolicy.gymDayToday()
      ) ?? WorkoutDatePolicy.gymDayToday()
    let studentID = UUID()
    let coachID = UUID()
    let exerciseID = UUID()
    let planExerciseID = UUID()
    let prescribedSets = (0...1).map { index in
      PrescribedSet(
        id: UUID(),
        setIndex: index,
        weightKg: 100,
        reps: 5,
        rpe: 8
      )
    }
    let exercise = StudentPlanExercise(
      id: planExerciseID,
      exercise: Exercise(
        id: exerciseID,
        name: "深蹲",
        exerciseType: .mainLift,
        mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad],
        equipment: [.barbell],
        movementPattern: [.squat],
        createdAt: planDayDate
      ),
      sequenceIndex: 0,
      prescribedSets: prescribedSets
    )
    let plan = StudentPlanView(
      cycleID: UUID(),
      weekIndex: 1,
      startDate: planDayDate,
      days: [
        StudentPlanDay(
          id: UUID(),
          date: planDayDate,
          exercises: [exercise]
        )
      ]
    )
    let logs = completedSetIndexes.map { index in
      StudentSetLog(
        id: UUID(),
        studentID: studentID,
        planExerciseID: planExerciseID,
        setIndex: index,
        loggedAt: planDayDate.addingTimeInterval(TimeInterval(index)),
        weightKg: 100,
        reps: 5,
        rpe: 8,
        completed: true
      )
    }
    let plans = InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    )
    let trainingLogs = InMemoryStudentTrainingLogRepository(seed: logs)
    let viewModel = TodayWorkoutViewModel(plans: plans, logs: trainingLogs)
    await viewModel.load(date: planDayDate, studentID: studentID)
    let chat = InMemoryChatRepository(
      currentUserID: studentID,
      seed: ChatDemoSeed(
        conversations: [],
        messagesByConversationID: [:],
        otherPartyNames: [coachID: "周教练"]
      )
    )
    let notifications = StudentNotificationsCoordinator(
      plans: plans,
      feedback: FeedbackInboxViewModel(
        repository: InMemoryStudentFeedbackRepository()
      ),
      evaluation: StudentEvaluationSummaryViewModel(
        summaries: InMemoryEvaluationSummaryRepository(),
        plans: plans,
        readStore: InMemoryEvaluationSummaryReadStore()
      ),
      activeCoach: ActiveCoachContext(
        coachID: coachID,
        coachDisplayName: "周教练"
      ),
      chatContext: StudentChatContext(
        repository: chat,
        currentUserID: studentID,
        inbox: ChatInboxViewModel(repository: chat, currentUserID: studentID),
        sendCoordinator: ChatSendCoordinator(
          repository: chat,
          currentUserID: studentID
        ),
        setRefSharing: SetRefSharingContext(load: { [] })
      )
    )
    return TodayWorkoutView(
      studentID: studentID,
      date: planDayDate,
      plans: plans,
      logs: trainingLogs,
      preloadedViewModel: viewModel,
      notifications: notifications
    )
  }
}
