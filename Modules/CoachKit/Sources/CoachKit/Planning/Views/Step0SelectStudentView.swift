import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step0SelectStudentView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 0")
          Text(CoachPlanningStrings.selectStudentPrompt)
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        if viewModel.availableStudents.isEmpty {
          PlanningNoStudentsState()
        } else {
          studentSection(
            title: CoachPlanningStrings.inEvaluation,
            students: students { status in
              if case .inEvaluation = status { return true }
              return false
            }
          )

          studentSection(
            title: CoachPlanningStrings.active,
            students: students { status in
              if case .active = status { return true }
              return false
            }
          )

          studentSection(
            title: CoachPlanningStrings.abnormal,
            students: students { status in
              if case .abnormal = status { return true }
              return false
            }
          )

          PrimaryButton(
            CoachPlanningStrings.startPlanning,
            isDisabled: viewModel.selectedStudent == nil,
            isFullWidth: true
          ) {
            Task {
              try? await viewModel.goNext()
            }
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
  }

  @ViewBuilder
  private func studentSection(
    title: String,
    students: [CoachStudentSummary]
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow("\(title) (\(students.count))", showsRule: false)

      VStack(spacing: 0) {
        ForEach(students) { student in
          StudentRow(
            student: student,
            isSelected: viewModel.selectedStudent?.id == student.id
          ) {
            viewModel.selectStudent(student)
            Task {
              try? await viewModel.goNext()
            }
          }

          if student.id != students.last?.id {
            Divider()
              .background(Color.MeetPR.border)
          }
        }
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
    }
  }

  private func students(
    matching predicate: (CoachStudentStatus) -> Bool
  ) -> [CoachStudentSummary] {
    viewModel.availableStudents.filter { predicate($0.status) }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct PlanningNoStudentsState: View {
  var body: some View {
    ContentUnavailableView(
      CoachPlanningStrings.noStudents,
      systemImage: "person.badge.plus",
      description: Text(CoachPlanningStrings.noStudentsSubtitle)
    )
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.xl)
  }
}

@MainActor
private struct StudentRow: View {
  let student: CoachStudentSummary
  let isSelected: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.md) {
        Text(leadingIcon)
          .font(Font.MeetPR.body)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(student.displayName)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Text(subtitle)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.green)
        }
      }
      .padding(MeetPRSpacing.base)
      .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface1)
    }
  }

  private var leadingIcon: String {
    switch student.status {
    case .inEvaluation:
      "⚠️"
    case .active:
      "•"
    case .abnormal:
      "🟡"
    }
  }

  private var subtitle: String {
    switch student.status {
    case .inEvaluation(let days, let hours):
      CoachPlanningStrings.evaluationRemaining(days: days, hours: hours)
    case .active:
      CoachPlanningStrings.readyForPlan
    case .abnormal(let reason):
      PlanningDisplay.abnormalReason(reason)
    }
  }
}

#if DEBUG
  #Preview("Step0SelectStudentView") {
    let viewModel = PlanningViewModel(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )

    Step0SelectStudentView(viewModel: viewModel)
      .task {
        await viewModel.bootstrap()
      }
  }
#endif
