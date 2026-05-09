import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct AccessoryMatchListSection: View {
  private let exercises: [Exercise]
  private let isLoading: Bool
  private let onAdd: @MainActor (Exercise) -> Void

  public init(
    exercises: [Exercise],
    isLoading: Bool,
    onAdd: @escaping @MainActor (Exercise) -> Void
  ) {
    self.exercises = exercises
    self.isLoading = isLoading
    self.onAdd = onAdd
  }

  public var body: some View {
    Card(accessibilityLabel: "Accessory matches") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text("匹配 \(exercises.count) 个")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        if isLoading {
          ProgressView("加载动作中")
            .font(Font.MeetPR.body)
        } else if exercises.isEmpty {
          Text("没有匹配动作")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          LazyVStack(spacing: MeetPRSpacing.sm) {
            ForEach(exercises) { exercise in
              AccessoryMatchRow(exercise: exercise) {
                onAdd(exercise)
              }
            }
          }
        }
      }
    }
  }
}

@MainActor
private struct AccessoryMatchRow: View {
  let exercise: Exercise
  let onAdd: @MainActor () -> Void

  var body: some View {
    Button(action: onAdd) {
      HStack(alignment: .center, spacing: MeetPRSpacing.md) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(exercise.name)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(PlanningDisplay.facetSummary(for: exercise))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Image(systemName: "plus.circle.fill")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("添加 \(exercise.name)")
  }
}
