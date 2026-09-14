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
      case month
    }

    let state: PreviewState
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
        sequenceContent: EmptyView(),
        calendarContent: TrainingCalendarPreview(month: state == .month),
        onRefresh: {},
        onReadiness: {},
        onNotifications: {},
        onMessageCoach: {},
        onAskCoach: {},
        onStart: {},
        onEdit: { _ in },
        onVideoAction: { _ in },
        onComplete: {},
        onUndoCompletion: {},
        onShowReview: {}
      )
    }

    private var content: TodayWorkoutScreen<EmptyView, TrainingCalendarPreview>.Content {
      .workout(
        TrainingPreviewFixtures.presentation(
          started: state != .list,
          complete: state == .complete || state == .readOnly
        )
      )
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private struct TrainingCalendarPreview: View {
    let month: Bool

    var body: some View {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point13) {
        HStack {
          Text(StudentStrings.localized(.todayWorkoutV3Previews002))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
          Spacer()
          Text(
            month
              ? StudentStrings.localized(.todayWorkoutV3Previews003)
              : StudentStrings.localized(.todayWorkoutV3Previews003)
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.white)
          .padding(.horizontal, MeetPRSpacing.point11)
          .padding(.vertical, MeetPRSpacing.point3)
          .background(month ? Color.MeetPR.borderStrong : Color.MeetPR.ctaFill)
          .clipShape(.rect(cornerRadius: MeetPRSpacing.point6))
        }

        if month {
          monthGrid
        } else {
          weekStrip
        }

        HStack(spacing: MeetPRSpacing.point14) {
          legend(Color.MeetPR.success, StudentStrings.localized(.todayWorkoutV3Previews004))
          legend(Color.MeetPR.gold500, StudentStrings.localized(.todayWorkoutV3Previews005))
          legend(Color.MeetPR.danger, StudentStrings.localized(.todayWorkoutV3Previews006))
        }
      }
    }

    private var weekStrip: some View {
      HStack(spacing: MeetPRSpacing.point6) {
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews007), date: 20, state: .done,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews008), date: 21, state: .future,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews009), date: 22, state: .done,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews010), date: 23, state: .done,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews011), date: 24, state: .today,
          isSelected: true,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews012), date: 25, state: .future,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
        MeetPRDayChip(
          weekday: StudentStrings.localized(.todayWorkoutV3Previews013), date: 26, state: .future,
          isSelected: false,
          width: nil, selectedAppearance: .outlined
        ) {}
      }
    }

    private var monthGrid: some View {
      let columns = Array(
        repeating: GridItem(.flexible(), spacing: MeetPRSpacing.point5),
        count: 7
      )
      return LazyVGrid(columns: columns, spacing: MeetPRSpacing.point5) {
        ForEach(
          [
            StudentStrings.localized(.todayWorkoutV3Previews014),
            StudentStrings.localized(.todayWorkoutV3Previews015),
            StudentStrings.localized(.todayWorkoutV3Previews016),
            StudentStrings.localized(.todayWorkoutV3Previews017),
            StudentStrings.localized(.todayWorkoutV3Previews018),
            StudentStrings.localized(.todayWorkoutV3Previews019),
            StudentStrings.localized(.todayWorkoutV3Previews020),
          ], id: \.self
        ) { label in
          Text(label)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textDim)
        }
        ForEach(1...35, id: \.self) { day in
          Text(day.formatted())
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
            .foregroundStyle(day > 31 ? Color.clear : Color.MeetPR.textPrimary)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.size46)
            .background(
              day == 24
                ? Color.MeetPR.surfaceElevated
                : Color.MeetPR.surfaceCard
            )
            .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
            .overlay {
              if day == 24 {
                RoundedRectangle(cornerRadius: MeetPRRadius.inset)
                  .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
              }
            }
        }
      }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
      HStack(spacing: MeetPRSpacing.point5) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text(text)
      }
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
      .foregroundStyle(Color.MeetPR.textDim)
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

  #Preview("Training · Month · Dark") {
    TodayWorkoutPreviewHarness(state: .month)
      .preferredColorScheme(.dark)
  }

  #Preview("Training · Month · Light") {
    TodayWorkoutPreviewHarness(state: .month)
      .preferredColorScheme(.light)
  }
#endif
