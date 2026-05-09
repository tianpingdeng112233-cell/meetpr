import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step3SelectMainLiftsView: View {
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
          Eyebrow("STEP 3")
          Text("选择主项变式")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        ForEach(viewModel.sortedAssignedDays, id: \.self) { day in
          MainLiftDaySection(dayOfWeek: day, viewModel: viewModel)
        }

        PrimaryButton(
          "下一步",
          isDisabled: !viewModel.isCurrentStepValid,
          isFullWidth: true
        ) {
          Task {
            try? await viewModel.goNext()
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("主项变式")
  }
}

@MainActor
private struct MainLiftDaySection: View {
  let dayOfWeek: Int
  @Bindable var viewModel: PlanningViewModel

  var body: some View {
    Card(accessibilityLabel: title) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text(title)
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        ForEach(viewModel.sortedLiftFamilies(in: dayOfWeek), id: \.self) { family in
          MainLiftPickerRow(
            dayOfWeek: dayOfWeek,
            family: family,
            viewModel: viewModel
          )
        }
      }
    }
  }

  private var title: String {
    let liftNames = viewModel.sortedLiftFamilies(in: dayOfWeek)
      .map(PlanningDisplay.liftName)
      .joined(separator: " + ")
    return "\(PlanningDisplay.weekdayName(dayOfWeek)) — \(liftNames)"
  }
}

@MainActor
private struct MainLiftPickerRow: View {
  let dayOfWeek: Int
  let family: LiftFamily
  @Bindable var viewModel: PlanningViewModel

  var body: some View {
    HStack(spacing: MeetPRSpacing.md) {
      Text("\(PlanningDisplay.liftName(family)):")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 56, alignment: .leading)

      Picker(
        PlanningDisplay.liftName(family),
        selection: selectedExerciseID
      ) {
        Text("请选择")
          .tag(Optional<UUID>.none)

        ForEach(viewModel.mainLiftCatalog[family] ?? []) { exercise in
          Text(exercise.name)
            .tag(Optional(exercise.id))
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var selectedExerciseID: Binding<UUID?> {
    Binding {
      viewModel.selectedVariants[key]
    } set: { newValue in
      viewModel.selectedVariants[key] = newValue
    }
  }

  private var key: DayLiftKey {
    DayLiftKey(dayOfWeek: dayOfWeek, liftFamily: family)
  }
}

#if DEBUG
  #Preview("Step3SelectMainLiftsView") {
    let viewModel = PlanningViewModel(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )

    Step3SelectMainLiftsView(viewModel: viewModel)
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
        }
      }
  }
#endif
