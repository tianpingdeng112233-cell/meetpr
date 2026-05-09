import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct SelectedAccessoryListSection: View {
  private let accessories: [DraftPlanExercise]
  private let exerciseProvider: @MainActor (UUID) -> Exercise?
  private let onDelete: @MainActor (UUID) -> Void

  public init(
    accessories: [DraftPlanExercise],
    exerciseProvider: @escaping @MainActor (UUID) -> Exercise?,
    onDelete: @escaping @MainActor (UUID) -> Void
  ) {
    self.accessories = accessories
    self.exerciseProvider = exerciseProvider
    self.onDelete = onDelete
  }

  public var body: some View {
    Card(accessibilityLabel: "Selected accessories") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text("已选 \(accessories.count) 个")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        if accessories.isEmpty {
          Text("当前训练日还没有辅助动作")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          LazyVStack(spacing: MeetPRSpacing.sm) {
            ForEach(accessories, id: \.id) { accessory in
              SelectedAccessoryRow(
                accessory: accessory,
                exercise: exerciseProvider(accessory.exerciseID)
              ) {
                onDelete(accessory.id)
              }
            }
          }
        }
      }
    }
  }
}

@MainActor
private struct SelectedAccessoryRow: View {
  let accessory: DraftPlanExercise
  let exercise: Exercise?
  let onDelete: @MainActor () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.md) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(exercise?.name ?? "未知动作")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(exercise.map(PlanningDisplay.facetSummary(for:)) ?? "无动作标签")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Button("删除", systemImage: "trash", action: onDelete)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.brandRed)
        .buttonStyle(.borderless)
    }
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .swipeActions(edge: .trailing) {
      Button(role: .destructive, action: onDelete) {
        Label("删除", systemImage: "trash")
      }
    }
    .accessibilityLabel(exercise?.name ?? "未知动作")
  }
}
