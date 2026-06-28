import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step4SelectAccessoriesView: View {
  @Bindable private var viewModel: PlanningViewModel
  @State private var showLibrary = false
  @State private var completionIssues: [String] = []

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
          Eyebrow("STEP 4")
          Text("添加辅助动作")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        DayChipBar(
          days: viewModel.sortedDraftDays,
          currentDayID: viewModel.currentDayID,
          dayTitle: { viewModel.dayLabel($0) },
          onSelect: { dayID in
            Task {
              await viewModel.switchToDay(dayID)
            }
          }
        )
        .padding(.horizontal, -MeetPRSpacing.base)

        if let selectedDayID = viewModel.currentDayID {
          let mainLifts = viewModel.mainLiftExercises(for: selectedDayID)
          let accessories = viewModel.selectedAccessories(for: selectedDayID)

          MainLiftSummarySection(viewModel: viewModel, exercises: mainLifts)

          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Text("已选 \(accessories.count) 个")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)

            ForEach(accessories, id: \.id) { exercise in
              ExerciseSetEditorCard(
                viewModel: viewModel,
                draftExercise: exercise
              ) {
                Task {
                  try? await viewModel.deleteAccessory(exercise.id, from: selectedDayID)
                }
              }
            }

            PrimaryButton(
              "+ 添加动作",
              isFullWidth: true
            ) {
              showLibrary = true
            }
          }

          PrimaryButton(
            "完成 — 进入规则配置",
            isFullWidth: true
          ) {
            // Remind instead of silently no-op'ing (David 2026-06-14): if a
            // day lacks a main lift or any exercise has no load set, list
            // the gaps rather than swallowing the validation error.
            let issues = viewModel.planCompletionIssues()
            if issues.isEmpty {
              Task { try? await viewModel.proceedToStep6() }
            } else {
              completionIssues = issues
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
    .scrollDismissesKeyboard(.interactively)
    .task {
      await selectInitialDayIfNeeded()
    }
    .sheet(isPresented: $showLibrary) {
      if let dayID = viewModel.currentDayID {
        AccessoryLibrarySheet(viewModel: viewModel, dayID: dayID)
      } else {
        Color.clear
      }
    }
    .alert("还差一点", isPresented: completionAlertBinding) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text("以下项目需要补全后才能进入下一步：\n\n" + completionIssues.joined(separator: "\n"))
    }
  }

  private var completionAlertBinding: Binding<Bool> {
    Binding(
      get: { !completionIssues.isEmpty },
      set: { isPresented in
        if !isPresented { completionIssues = [] }
      }
    )
  }

  private func selectInitialDayIfNeeded() async {
    if let currentDayID = viewModel.currentDayID {
      await viewModel.switchToDay(currentDayID)
    } else if let firstDayID = viewModel.sortedDraftDays.first?.id {
      await viewModel.switchToDay(firstDayID)
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct MainLiftSummarySection: View {
  @Bindable var viewModel: PlanningViewModel
  let exercises: [DraftPlanExercise]

  var body: some View {
    Card(accessibilityLabel: "Selected main lifts") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        HStack {
          VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
            Text("本日主项")
              .font(Font.MeetPR.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text("上一步选择的主项、变式和 W1 强度")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }

          Spacer()

          StatusBadge(status: .live, title: "\(exercises.count) 项")
        }

        ForEach(exercises, id: \.id) { exercise in
          MainLiftSummaryRow(viewModel: viewModel, draftExercise: exercise)
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct MainLiftSummaryRow: View {
  @Bindable var viewModel: PlanningViewModel
  let draftExercise: DraftPlanExercise

  var body: some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.sm) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        HStack(spacing: MeetPRSpacing.xs) {
          Text(familyName)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)

          StatusBadge(status: .live, title: "主项")
        }

        Text(viewModel.exerciseName(for: draftExercise))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: MeetPRSpacing.sm)

      Text(intensityText)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
    }
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  private var familyName: String {
    guard let family = viewModel.catalogExercise(for: draftExercise)?.mainLiftFamily else {
      return "主项"
    }
    return PlanningDisplay.liftName(family)
  }

  private var intensityText: String {
    let spec =
      viewModel.setSpec(for: draftExercise.id)
      ?? viewModel.defaultSetSpec(for: draftExercise)
    let repsText =
      if let targetRepsMax = spec.targetRepsMax {
        "\(spec.targetReps)-\(targetRepsMax)"
      } else {
        "\(spec.targetReps)"
      }

    return "\(spec.setCount) 组 x \(repsText) 次 · \(intensityValueText(for: spec))"
  }

  private func intensityValueText(for spec: DraftSetSpec) -> String {
    switch spec.intensityMode {
    case .weight:
      "\(spec.targetValue.planningFormatted())kg"
    case .rpe:
      "@RPE \(spec.targetValue.planningFormatted())"
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
