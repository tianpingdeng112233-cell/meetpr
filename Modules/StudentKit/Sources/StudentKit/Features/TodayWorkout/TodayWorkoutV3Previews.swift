#if DEBUG
  import CoreModels
  import DesignSystem
  import SwiftUI

  @available(iOS 17.0, macOS 14.0, *)
  @MainActor
  private struct TodayWorkoutPreviewHarness: View {
    enum PreviewState {
      case list
      case recording
      case complete
      case readOnly
    }

    let state: PreviewState
    @State private var selectedDayID: UUID?
    @State private var collapsed: [UUID: Bool] = [:]

    init(state: PreviewState) {
      self.state = state
    }

    var body: some View {
      TodayWorkoutScreen(
        content: content,
        weekCode: "W1D4",
        dayState: state == .readOnly ? .completed(canUndo: true) : .current,
        reviewCompleted: false,
        unreadCount: 3,
        showsNotifications: true,
        coachName: StudentStrings.localized(.todayWorkoutV3Previews001),
        showsAskCoach: state == .recording || state == .complete,
        isPreparingAskCoach: false,
        collapsedExercises: $collapsed,
        sequenceContent: TrainingWeekStrip(
          days: StudentDemoSeed.makePlanView().days, selectedDayID: $selectedDayID
        ),
        showsBackToToday: state == .readOnly,
        onBackToToday: {},
        onRefresh: {},
        onHistory: {},
        onReadiness: {},
        onNotifications: {},
        onMessageCoach: {},
        onAskCoach: {},
        onStart: {},
        onQuickLog: {},
        onEdit: { _ in },
        onVideoAction: { _ in },
        onComplete: {},
        onUndoCompletion: {},
        onShowReview: {}
      )
    }

    private var content: TodayWorkoutScreen<TrainingWeekStrip>.Content {
      .workout(
        TrainingPreviewFixtures.presentation(
          started: state != .list,
          complete: state == .complete || state == .readOnly
        )
      )
    }
  }

  @MainActor
  private enum TrainingPreviewFixtures {
    static let date =
      Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 24)
      ) ?? Date()

    static func presentation(
      started: Bool,
      complete: Bool
    ) -> TodayWorkoutPresentation {
      let day = makeDay()
      var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
      if started {
        drafts[0].completed = true
        drafts[0].actualWeight = 175
        drafts[0].actualReps = 3
        drafts[0].actualRPE = 8.5
      }
      if complete {
        for index in drafts.indices {
          drafts[index].completed = true
          drafts[index].actualWeight = drafts[index].prescribed.weightKg
          drafts[index].actualReps = drafts[index].prescribed.reps
          drafts[index].actualRPE = drafts[index].prescribed.rpe
        }
      }
      return TodayWorkoutPresentation(
        day: day,
        drafts: drafts,
        references: [:],
        started: started
      )
    }

    private static func makeDay() -> StudentPlanDay {
      StudentPlanDay(
        id: UUID(),
        date: date,
        exercises: [
          exercise(
            StudentStrings.localized(.todayWorkoutV3Previews021), sequence: 0, weight: 175, reps: 3,
            note: StudentStrings.localized(.todayWorkoutV3Previews022)),
          exercise(
            StudentStrings.localized(.todayWorkoutV3Previews023), sequence: 1, weight: 110, reps: 3,
            note: StudentStrings.localized(.todayWorkoutV3Previews024)),
          exercise(
            StudentStrings.localized(.todayWorkoutV3Previews025), sequence: 2, weight: 190, reps: 2,
            note: StudentStrings.localized(.todayWorkoutV3Previews026)),
        ]
      )
    }

    private static func exercise(
      _ name: String,
      sequence: Int,
      weight: Decimal,
      reps: Int,
      note: String
    ) -> StudentPlanExercise {
      StudentPlanExercise(
        id: UUID(),
        exercise: Exercise(
          id: UUID(),
          name: name,
          exerciseType: .mainLift,
          isCompetitionLift: true,
          muscleGroups: [],
          equipment: [],
          createdAt: date
        ),
        sequenceIndex: sequence,
        prescribedSets: (0..<3).map { index in
          PrescribedSet(
            id: UUID(),
            setIndex: index,
            weightKg: weight,
            reps: reps,
            rpe: 8.5,
            coachNote: note
          )
        },
        notes: note
      )
    }
  }

  #Preview("Training · List · Dark") {
    TodayWorkoutPreviewHarness(state: .list)
      .preferredColorScheme(.dark)
  }

  #Preview("Training · List · Light") {
    TodayWorkoutPreviewHarness(state: .list)
      .preferredColorScheme(.light)
  }

  #Preview("Training · Recording · Dark") {
    TodayWorkoutPreviewHarness(state: .recording)
      .preferredColorScheme(.dark)
  }

  #Preview("Training · Recording · Light") {
    TodayWorkoutPreviewHarness(state: .recording)
      .preferredColorScheme(.light)
  }

  #Preview("Training · Complete · Dark") {
    TodayWorkoutPreviewHarness(state: .complete)
      .preferredColorScheme(.dark)
  }

  #Preview("Training · Complete · Light") {
    TodayWorkoutPreviewHarness(state: .complete)
      .preferredColorScheme(.light)
  }

  #Preview("Training · Read-only · Dark") {
    TodayWorkoutPreviewHarness(state: .readOnly)
      .preferredColorScheme(.dark)
  }

  #Preview("Training · Read-only · Light") {
    TodayWorkoutPreviewHarness(state: .readOnly)
      .preferredColorScheme(.light)
  }

#endif
