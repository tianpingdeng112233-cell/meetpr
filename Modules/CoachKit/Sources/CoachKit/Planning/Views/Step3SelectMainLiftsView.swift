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
          PlanningStudentHeaderView(student: student, profile: viewModel.loadedProfile)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 3")
          Text("选择主项及变式")
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
    .navigationTitle("主项及变式")
    .scrollDismissesKeyboard(.interactively)
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
    return "\(viewModel.dayLabel(dayOfWeek)) — \(liftNames)"
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct MainLiftPickerRow: View {
  let dayOfWeek: Int
  let family: LiftFamily
  @Bindable var viewModel: PlanningViewModel
  @State private var showingPicker = false

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      HStack(spacing: MeetPRSpacing.md) {
        Text("\(PlanningDisplay.liftName(family)):")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(width: 56, alignment: .leading)

        Button {
          showingPicker = true
        } label: {
          HStack(spacing: MeetPRSpacing.xs) {
            Text(currentSelectionLabel)
              .font(Font.MeetPR.body)
              .foregroundStyle(
                currentSelection == nil ? Color.MeetPR.fgTertiary : Color.MeetPR.fgPrimary
              )
              .lineLimit(1)
              .truncationMode(.tail)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
              .font(.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, MeetPRSpacing.xs)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(
          "\(PlanningDisplay.liftName(family))主项及变式: \(currentSelectionLabel)"
        )
      }

      if let draftExercise = viewModel.mainLiftDraftExercise(for: key) {
        ExerciseSetEditorCard(viewModel: viewModel, draftExercise: draftExercise)
      }
    }
    .sheet(isPresented: $showingPicker) {
      VariantPickerSheet(
        family: family,
        variants: viewModel.sortedMainLiftVariants(for: family),
        selectedID: currentSelection?.id,
        onSelect: { exercise in
          try? viewModel.pickMainLiftVariant(exercise.id, for: key)
          showingPicker = false
        }
      )
    }
  }

  private var currentSelection: Exercise? {
    guard let selectedID = viewModel.selectedVariants[key] else { return nil }
    return (viewModel.mainLiftCatalog[family] ?? []).first { $0.id == selectedID }
  }

  private var currentSelectionLabel: String {
    guard let exercise = currentSelection else { return "请选择" }
    if let nameEn = exercise.nameEn {
      return "\(exercise.name)  ·  \(nameEn)"
    }
    return exercise.name
  }

  private var key: DayLiftKey {
    DayLiftKey(dayOfWeek: dayOfWeek, liftFamily: family)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct VariantPickerSheet: View {
  let family: LiftFamily
  let variants: [Exercise]
  let selectedID: UUID?
  let onSelect: (Exercise) -> Void

  @State private var searchText = ""
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(filteredVariants, id: \.id) { exercise in
        Button {
          onSelect(exercise)
        } label: {
          HStack(spacing: MeetPRSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
              Text(exercise.name)
                .font(Font.MeetPR.body)
                .foregroundStyle(Color.MeetPR.fgPrimary)
              if let nameEn = exercise.nameEn {
                Text(nameEn)
                  .font(Font.MeetPR.footnote)
                  .foregroundStyle(Color.MeetPR.fgSecondary)
              }
            }
            Spacer()
            if exercise.id == selectedID {
              Image(systemName: "checkmark")
                .foregroundStyle(Color.MeetPR.brandRed)
            }
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
      .listStyle(.plain)
      .searchable(text: $searchText, prompt: "搜索 / Search")
      .navigationTitle("\(PlanningDisplay.liftName(family))主项及变式")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
      }
    }
  }

  private var filteredVariants: [Exercise] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return variants }
    return variants.filter { exercise in
      exercise.name.localizedStandardContains(trimmed)
        || (exercise.nameEn?.localizedStandardContains(trimmed) ?? false)
    }
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
