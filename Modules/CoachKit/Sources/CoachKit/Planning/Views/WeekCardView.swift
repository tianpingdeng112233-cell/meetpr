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

          Eyebrow(footerText, color: Color.MeetPR.textTertiary, showsRule: false)

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
          .foregroundStyle(Color.MeetPR.textTertiary)
        }
      }
      .scrollIndicators(.hidden)
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("Week \(weekNumber) / \(weekCount)")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      StatusBadge(
        status: weekNumber == 1 ? .completed : .pending, title: weekNumber == 1 ? "基线" : "推导")
    }
  }

  private var footerText: String {
    if weekNumber == 1 {
      "Week 1 是基线（你手填的）"
    } else {
      "Week \(weekNumber) 由规则推导"
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
      Eyebrow(viewModel.dayLabel(day.dayOfWeek), color: Color.MeetPR.textTertiary)

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
            .foregroundStyle(Color.MeetPR.textPrimary)
          if isMainLift {
            StatusBadge(status: .live, title: "主项")
          }
        }
        Text("\(spec.setCount) 组 × \(spec.targetReps) 次")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }

      Spacer()

      Text(intensityText)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .monospacedDigit()
    }
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surfaceElevated)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .contextMenu {
      Button("查看详情", systemImage: "info.circle") {}
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
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("\(spec.setCount) 组 × \(spec.targetReps) 次")
      Text(detail)
      if let notes = spec.notes, !notes.isEmpty {
        Text(notes)
      }
      Text("PR / e1RM：TODO spec NNN backend wiring")
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .font(Font.MeetPR.footnote)
    .foregroundStyle(Color.MeetPR.textSecondary)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surfaceCard)
  }

  private var detail: String {
    switch spec.intensityMode {
    case .weight:
      return "强度：\(spec.targetValue.planningFormatted())kg"
    case .rpe:
      return "强度：@RPE \(spec.targetValue.planningFormatted())"
    }
  }
}
