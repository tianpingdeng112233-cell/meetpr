import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step2AssignFrequencyView: View {
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
          Eyebrow("STEP 2")
          Text("定 SBD 频率")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        HStack(spacing: MeetPRSpacing.sm) {
          SecondaryButton("使用模板", isDisabled: true, isFullWidth: true) {}
          SecondaryButton("复制上周", isDisabled: true, isFullWidth: true) {}
        }

        Eyebrow("或从零开始")

        Card(accessibilityLabel: "Training days") {
          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Text("训练日")
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(trainingDaySummary)
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text("三大项每周各练几次？")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          FrequencyControl(
            title: "深蹲",
            value: viewModel.sbdFrequency.squat,
            maxFrequency: maxFrequency
          ) { delta in
            adjust(.squat, by: delta)
          }

          FrequencyControl(
            title: "卧推",
            value: viewModel.sbdFrequency.bench,
            maxFrequency: maxFrequency
          ) { delta in
            adjust(.bench, by: delta)
          }

          FrequencyControl(
            title: "硬拉",
            value: viewModel.sbdFrequency.deadlift,
            maxFrequency: maxFrequency
          ) { delta in
            adjust(.deadlift, by: delta)
          }
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text("分配到训练日")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          ForEach(viewModel.assignmentDisplayDays, id: \.self) { day in
            AssignmentDayCard(dayOfWeek: day, viewModel: viewModel)
          }
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
    .navigationTitle("频率分配")
  }

  private var trainingDaySummary: String {
    let count = viewModel.assignmentDisplayDays.count
    guard viewModel.preferredTrainingDays.isEmpty else {
      return "每周 \(count) 个训练日 · 来自学员资料"
    }
    return "每周 \(count) 个训练日"
  }

  private func adjust(_ family: LiftFamily, by delta: Int) {
    var frequency = viewModel.sbdFrequency
    switch family {
    case .squat:
      frequency.squat = clamped(frequency.squat + delta)
    case .bench:
      frequency.bench = clamped(frequency.bench + delta)
    case .deadlift:
      frequency.deadlift = clamped(frequency.deadlift + delta)
    }
    viewModel.sbdFrequency = frequency
  }

  private func clamped(_ value: Int) -> Int {
    min(max(value, 0), maxFrequency)
  }

  private var maxFrequency: Int {
    // Capped by the assignable slots (the student's training days), not 7 —
    // a frequency above the slot count could never be fully assigned and
    // would deadlock 下一步 (Codex review).
    viewModel.assignmentDisplayDays.count
  }
}

@MainActor
private struct FrequencyControl: View {
  let title: String
  let value: Int
  let maxFrequency: Int
  let adjust: @MainActor (Int) -> Void

  var body: some View {
    Card(accessibilityLabel: "\(title) frequency") {
      HStack(spacing: MeetPRSpacing.base) {
        Text(title)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        Spacer()

        Button {
          adjust(-1)
        } label: {
          Image(systemName: "minus")
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.bordered)
        .disabled(value <= 0)

        Text("\(value) 次/周")
          .font(Font.MeetPR.bodyEmphasis)
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(minWidth: 72)

        Button {
          adjust(1)
        } label: {
          Image(systemName: "plus")
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.bordered)
        .disabled(value >= maxFrequency)
      }
    }
  }
}

@MainActor
private struct AssignmentDayCard: View {
  let dayOfWeek: Int
  @Bindable var viewModel: PlanningViewModel

  var body: some View {
    Card(accessibilityLabel: viewModel.dayLabel(dayOfWeek)) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        HStack {
          Text(viewModel.dayLabel(dayOfWeek))
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Spacer()

          StatusBadge(status: .pending, title: "\(viewModel.assignedCount(for: dayOfWeek)) 项")
        }

        HStack(spacing: MeetPRSpacing.sm) {
          ForEach(LiftFamily.allCases, id: \.self) { family in
            LiftChip(
              title: PlanningDisplay.liftName(family),
              isSelected: viewModel.dayAssignments[dayOfWeek]?.contains(family) == true
            ) {
              viewModel.toggleAssignment(dayOfWeek: dayOfWeek, liftFamily: family)
            }
          }
        }
      }
    }
  }
}

@MainActor
private struct LiftChip: View {
  let title: String
  let isSelected: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(isSelected ? Color.MeetPR.bg : Color.MeetPR.fgPrimary)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.surface2)
        .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
    }
    .buttonStyle(.plain)
  }
}

#if DEBUG
  #Preview("Step2AssignFrequencyView") {
    let viewModel = PlanningViewModel(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )

    Step2AssignFrequencyView(viewModel: viewModel)
      .task {
        await viewModel.bootstrap()
        if let student = viewModel.availableStudents.first(where: { summary in
          if case .active = summary.status { return true }
          return false
        }) {
          viewModel.selectStudent(student)
          viewModel.selectDuration(4)
        }
      }
  }
#endif
