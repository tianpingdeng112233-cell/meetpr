import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step4SelectAccessoriesView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        if let student = viewModel.selectedStudent {
          PlanningStudentHeaderView(student: student)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 4")
          Text("添加辅助动作")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        DayChipBar(
          days: viewModel.sortedDraftDays,
          currentDayID: viewModel.currentDayID
        ) { dayID in
          Task {
            await viewModel.switchToDay(dayID)
          }
        }
        .padding(.horizontal, -MeetPRSpacing.base)

        if let selectedDayID = viewModel.currentDayID {
          AccessoryFilterSection(
            filters: viewModel.accessoryFilters(for: selectedDayID),
            onChange: { filters in
              Task {
                await viewModel.updateFilters(filters, for: selectedDayID)
              }
            }
          )

          AccessoryMatchListSection(
            exercises: viewModel.availableAccessories(for: selectedDayID),
            selectedExerciseIDs: Set(
              viewModel.selectedAccessories(for: selectedDayID).map(\.exerciseID)
            ),
            isLoading: viewModel.isLoadingAccessories
          ) { exercise in
            Task {
              try? await viewModel.addAccessory(exercise, to: selectedDayID)
            }
          }

          SelectedAccessoryListSection(
            accessories: viewModel.selectedAccessories(for: selectedDayID),
            exerciseProvider: viewModel.accessoryExercise(for:)
          ) { draftExerciseID in
            Task {
              try? await viewModel.deleteAccessory(draftExerciseID, from: selectedDayID)
            }
          }

          PrimaryButton(
            "完成辅助动作 — 填写 W1 强度",
            isFullWidth: true
          ) {
            Task {
              try? await viewModel.proceedToStep5()
            }
          }
        } else {
          Card(accessibilityLabel: "No training days") {
            Text("请先完成训练日分配")
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("辅助动作")
    .task {
      await selectInitialDayIfNeeded()
    }
  }

  private func selectInitialDayIfNeeded() async {
    if let currentDayID = viewModel.currentDayID {
      await viewModel.switchToDay(currentDayID)
    } else if let firstDayID = viewModel.sortedDraftDays.first?.id {
      await viewModel.switchToDay(firstDayID)
    }
  }
}

#if DEBUG
  #Preview("Step4SelectAccessoriesView") {
    let viewModel = PlanningViewModel(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )

    Step4SelectAccessoriesView(viewModel: viewModel)
      .task {
        await viewModel.bootstrap()
        if let student = viewModel.availableStudents.first(where: { summary in
          if case .active = summary.status { return true }
          return false
        }) {
          viewModel.selectStudent(student)
          viewModel.selectDuration(4)
          viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
          viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
          viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)
          viewModel.toggleAssignment(dayOfWeek: 5, liftFamily: .deadlift)
          viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] =
            viewModel.mainLiftCatalog[.squat]?.first?.id
          viewModel.selectedVariants[DayLiftKey(dayOfWeek: 3, liftFamily: .bench)] =
            viewModel.mainLiftCatalog[.bench]?.first?.id
          viewModel.selectedVariants[DayLiftKey(dayOfWeek: 5, liftFamily: .deadlift)] =
            viewModel.mainLiftCatalog[.deadlift]?.first?.id
          try? await viewModel.goNext()
        }
      }
  }
#endif
