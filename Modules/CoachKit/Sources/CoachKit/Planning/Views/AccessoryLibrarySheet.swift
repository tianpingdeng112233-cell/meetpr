import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct AccessoryLibrarySheet: View {
  @Bindable private var viewModel: PlanningViewModel
  private let dayID: UUID
  @Environment(\.dismiss) private var dismiss

  public init(viewModel: PlanningViewModel, dayID: UUID) {
    self.viewModel = viewModel
    self.dayID = dayID
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          AccessoryFilterSection(
            filters: viewModel.accessoryFilters(for: dayID),
            onChange: { filters in
              Task {
                await viewModel.updateFilters(filters, for: dayID)
              }
            }
          )

          AccessoryMatchListSection(
            exercises: viewModel.availableAccessories(for: dayID),
            selectedExerciseIDs: Set(
              viewModel.selectedAccessories(for: dayID).map(\.exerciseID)
            ),
            isLoading: viewModel.isLoadingAccessories
          ) { exercise in
            Task {
              let isSelected = viewModel.selectedAccessories(for: dayID)
                .contains { $0.exerciseID == exercise.id }
              if isSelected {
                try? await viewModel.removeAccessory(catalogID: exercise.id, from: dayID)
              } else {
                try? await viewModel.addAccessory(exercise, to: dayID)
              }
            }
          }
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle(CoachPlanningStrings.exerciseLibrary)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(CoachPlanningStrings.done) { dismiss() }
        }
      }
    }
  }
}
