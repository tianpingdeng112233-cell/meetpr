#if DEBUG
  import CoreModels
  import DesignSystem
  import SwiftUI

  @available(iOS 17.0, macOS 14.0, *)
  @MainActor
  private struct W4FeedbackPreview: View {
    enum Scenario {
      case unread
      case read
      case noVideo
    }

    let scenario: Scenario
    @State private var viewModel: FeedbackInboxViewModel

    init(scenario: Scenario) {
      self.scenario = scenario
      self._viewModel = State(
        initialValue: FeedbackInboxViewModel(
          repository: InMemoryStudentFeedbackRepository(
            seed: [Self.feedback(scenario: scenario)]
          )
        )
      )
    }

    var body: some View {
      NavigationStack {
        FeedbackInboxView(
          studentID: StudentDemoSeed.studentID,
          viewModel: viewModel
        )
      }
    }

    private static func feedback(scenario: Scenario) -> CoachFeedback {
      let videoID = UUID()
      let hasVideo = scenario != .noVideo
      return CoachFeedback(
        id: UUID(),
        coachID: StudentDemoSeed.coachID,
        studentID: StudentDemoSeed.studentID,
        dayDate: W4PreviewFixtures.date,
        videoID: hasVideo ? videoID : nil,
        video: hasVideo
          ? CoachFeedbackVideo(
            id: videoID,
            exerciseName: StudentStrings.localized(.w4V3Previews001),
            setIndex: 1,
            weightKg: "175",
            reps: 3,
            loggedAt: W4PreviewFixtures.date
          )
          : nil,
        text: StudentStrings.localized(.w4V3Previews002),
        postedAt: W4PreviewFixtures.date,
        readAt: scenario == .read ? W4PreviewFixtures.date : nil
      )
    }
  }

  @MainActor
  private enum W4PreviewFixtures {
    static let date =
      Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 24)
      ) ?? Date(timeIntervalSince1970: 0)

    static func presentation(
      hasPersonalRecord: Bool,
      streak: Int?
    ) -> WorkoutCompletionPresentation {
      let day = makeDay()
      var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
      for index in drafts.indices {
        drafts[index].actualWeight = drafts[index].prescribed.weightKg
        drafts[index].actualReps = drafts[index].prescribed.reps
        drafts[index].actualRPE = drafts[index].prescribed.rpe
        drafts[index].completed = true
      }
      if drafts.indices.contains(0) {
        drafts[0].actualWeight = 175
        drafts[0].actualReps = 4
      }
      let firstExerciseID = day.exercises.first?.exercise.id
      let references =
        firstExerciseID.map {
          [
            $0:
              ExerciseReference(
                last: nil,
                best: ExerciseReferenceSet(
                  reps: hasPersonalRecord ? 3 : 5,
                  weightKg: 175
                )
              )
          ]
        } ?? [:]
      return WorkoutCompletionPresentation(
        day: day,
        drafts: drafts,
        references: references,
        weekCode: "W1D4",
        coachName: StudentStrings.localized(.w4V3Previews003),
        streak: streak,
        previousVolumeChangePercent: 6
      )
    }

    private static func makeDay() -> StudentPlanDay {
      StudentPlanDay(
        id: UUID(),
        date: date,
        exercises: [
          exercise(
            StudentStrings.localized(.w4V3Previews001),
            sequence: 0, weight: 175, reps: 3, rpe: 8.5),
          exercise(
            StudentStrings.localized(.w4V3Previews004),
            sequence: 1, weight: 110, reps: 5, rpe: 8),
          exercise(
            StudentStrings.localized(.w4V3Previews005),
            sequence: 2, weight: 190, reps: 2, rpe: 8.5),
        ]
      )
    }

    private static func exercise(
      _ name: String,
      sequence: Int,
      weight: Decimal,
      reps: Int,
      rpe: Decimal
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
            rpe: rpe
          )
        }
      )
    }
  }

  #Preview("W4 · Celebration · PR + Streak · Dark") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: 12
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.dark)
  }

  #Preview("W4 · Celebration · PR + Streak · Light") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: 12
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.light)
  }

  #Preview("W4 · Celebration · PR + No Streak · Dark") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: nil
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.dark)
  }

  #Preview("W4 · Celebration · PR + No Streak · Light") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: nil
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.light)
  }

  #Preview("W4 · Celebration · No PR + Streak · Dark") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: false,
        streak: 12
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.dark)
  }

  #Preview("W4 · Celebration · No PR + Streak · Light") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: false,
        streak: 12
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.light)
  }

  #Preview("W4 · Celebration · No PR + No Streak · Dark") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: false,
        streak: nil
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.dark)
  }

  #Preview("W4 · Celebration · No PR + No Streak · Light") {
    WorkoutCelebrationView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: false,
        streak: nil
      ),
      onOpenReview: {},
      onFinish: {}
    )
    .preferredColorScheme(.light)
  }

  #Preview("W4 · Review · Dark") {
    SessionSummaryView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: nil
      ),
      studentID: StudentDemoSeed.studentID,
      onComplete: {}
    )
    .preferredColorScheme(.dark)
  }

  #Preview("W4 · Review · Light") {
    SessionSummaryView(
      presentation: W4PreviewFixtures.presentation(
        hasPersonalRecord: true,
        streak: nil
      ),
      studentID: StudentDemoSeed.studentID,
      onComplete: {}
    )
    .preferredColorScheme(.light)
  }

  #Preview("W4 · Feedback · Unread · Dark") {
    W4FeedbackPreview(scenario: .unread)
      .preferredColorScheme(.dark)
  }

  #Preview("W4 · Feedback · Unread · Light") {
    W4FeedbackPreview(scenario: .unread)
      .preferredColorScheme(.light)
  }

  #Preview("W4 · Feedback · Read · Dark") {
    W4FeedbackPreview(scenario: .read)
      .preferredColorScheme(.dark)
  }

  #Preview("W4 · Feedback · Read · Light") {
    W4FeedbackPreview(scenario: .read)
      .preferredColorScheme(.light)
  }

  #Preview("W4 · Feedback · No Video · Dark") {
    W4FeedbackPreview(scenario: .noVideo)
      .preferredColorScheme(.dark)
  }

  #Preview("W4 · Feedback · No Video · Light") {
    W4FeedbackPreview(scenario: .noVideo)
      .preferredColorScheme(.light)
  }
#endif
