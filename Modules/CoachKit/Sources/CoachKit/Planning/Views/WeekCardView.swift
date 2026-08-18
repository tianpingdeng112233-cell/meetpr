import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct WeekCardView: View {
  @Bindable private var viewModel: PlanningViewModel
  private let weekNumber: Int

  public init(viewModel: PlanningViewModel, weekNumber: Int) {
    self.viewModel = viewModel
    self.weekNumber = weekNumber
  }

  public var body: some View {
    Card(accessibilityLabel: "Week card") {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          header

          ForEach(viewModel.sortedDraftDays, id: \.id) { day in
            WeekCardDaySection(viewModel: viewModel, day: day, weekNumber: weekNumber)
          }

          Eyebrow(footerText, color: Color.MeetPR.fgTertiary, showsRule: false)

          HStack {
            if weekNumber > 1 {
              Text("← swipe to Week \(weekNumber - 1)")
            }
            Spacer()
            if weekNumber < weekCount {
              Text("swipe to Week \(weekNumber + 1) →")
            }
          }
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .scrollIndicators(.hidden)
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(CoachPlanningStrings.weekPosition(weekNumber, total: weekCount))
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      StatusBadge(
        status: weekNumber == 1 ? .completed : .pending,
        title: weekNumber == 1 ? CoachPlanningStrings.baseline : CoachPlanningStrings.derived
      )
    }
  }

  private var footerText: String {
    if weekNumber == 1 {
      CoachPlanningStrings.baselineFooter()
    } else {
      CoachPlanningStrings.derivedFooter(weekNumber)
    }
  }

  private var weekCount: Int {
    max(1, viewModel.draftPlan?.planWeeks ?? viewModel.planWeeks ?? 1)
  }
}

@MainActor
private struct WeekCardDaySection: View {
  @Bindable var viewModel: PlanningViewModel
  let day: DraftPlanDay
  let weekNumber: Int

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow(viewModel.dayLabel(day.dayOfWeek), color: Color.MeetPR.fgTertiary)

      ForEach(viewModel.sortedExercises(in: day), id: \.id) { exercise in
        if let spec = viewModel.derivedSetSpec(forWeek: weekNumber, draftExercise: exercise) {
          WeekExerciseRow(
            title: viewModel.exerciseName(for: exercise),
            isMainLift: exercise.isMainLift,
            spec: spec
          )
        }
      }
    }
  }
}

@MainActor
private struct WeekExerciseRow: View {
  let title: String
  let isMainLift: Bool
  let spec: DraftSetSpec

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        HStack(spacing: MeetPRSpacing.xs) {
          Text(title)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          if isMainLift {
            StatusBadge(status: .live, title: CoachPlanningStrings.mainLift)
          }
        }
        Text(CoachPlanningStrings.setAndRepCount(sets: spec.setCount, reps: spec.targetReps))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      Spacer()

      Text(intensityText)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
    }
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .contextMenu {
      Button(CoachPlanningStrings.viewDetails, systemImage: "info.circle") {}
        .disabled(true)
    } preview: {
      ExercisePeekView(title: title, spec: spec)
    }
  }

  private var intensityText: String {
    switch spec.intensityMode {
    case .weight:
      return "\(spec.targetValue.planningFormatted())kg"
    case .rpe:
      return "@RPE \(spec.targetValue.planningFormatted())"
    }
  }
}

@MainActor
private struct ExercisePeekView: View {
  let title: String
  let spec: DraftSetSpec

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(title)
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text(CoachPlanningStrings.setAndRepCount(sets: spec.setCount, reps: spec.targetReps))
      Text(detail)
      if let notes = spec.notes, !notes.isEmpty {
        Text(notes)
      }
      Text("PR / e1RM：TODO spec NNN backend wiring")
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .font(Font.MeetPR.footnote)
    .foregroundStyle(Color.MeetPR.fgSecondary)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surface1)
  }

  private var detail: String {
    switch spec.intensityMode {
    case .weight:
      return CoachPlanningStrings.intensityWeight(spec.targetValue.planningFormatted())
    case .rpe:
      return CoachPlanningStrings.intensityRPE(spec.targetValue.planningFormatted())
    }
  }
}
