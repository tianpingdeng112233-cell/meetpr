import CoreModels
import DesignSystem
import SwiftUI

struct StudentExercisePicker: View {
  let viewModel: TodayWorkoutViewModel
  let day: StudentPlanDay
  let addedIDs: Set<UUID>
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""
  @State private var tag: StudentExerciseTag = .all

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
          TextField(StudentStrings.localized(.addedSearch), text: $search)
            .textFieldStyle(.roundedBorder)
          ForEach(StudentExerciseTag.rows.indices, id: \.self) { index in
            StudentTagLayout {
              ForEach(StudentExerciseTag.rows[index], id: \.self) { item in
                Button(item.title) { tag = item }
                  .font(.caption).padding(.horizontal, MeetPRSpacing.space2)
                  .frame(minHeight: MeetPRSpacing.minimumHitTarget)
                  .foregroundStyle(tag == item ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary)
                  .background(
                    tag == item ? Color.MeetPR.textPrimary : Color.MeetPR.surfaceCard, in: .capsule
                  )
                  .overlay { Capsule().strokeBorder(Color.MeetPR.borderStrong, lineWidth: 1) }
              }
            }
          }
          LazyVStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
            ForEach(filteredExercises) { exercise in
              let inPlan = day.exercises.contains { $0.exercise.id == exercise.id }
              let alreadyAdded = addedIDs.contains(exercise.id)
              Button {
                viewModel.addStudentExercise(exercise)
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
                  Text(StudentExerciseName.display(exercise)).font(.headline)
                  Text(
                    inPlan
                      ? StudentStrings.localized(.addedInPlan)
                      : alreadyAdded
                        ? StudentStrings.localized(.addedAlreadyAdded)
                        : subtitle(exercise)
                  )
                  .font(.caption).foregroundStyle(Color.MeetPR.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MeetPRSpacing.space3)
                .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
              }
              .buttonStyle(.plain).disabled(inPlan || alreadyAdded)
              .opacity(inPlan || alreadyAdded ? 0.5 : 1)
            }
          }
        }
        .padding(MeetPRSpacing.space3)
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Color.MeetPR.bgBase)
      .navigationTitle(StudentStrings.localized(.addedAddExercise))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(StudentStrings.localized(.addedCancel), systemImage: "xmark") { dismiss() }
        }
      }
      .task { await viewModel.loadExerciseCatalog() }
    }
  }

  private var filteredExercises: [Exercise] {
    viewModel.exerciseCatalog.filter { tag.matches($0, search: search) }
  }

  private func subtitle(_ exercise: Exercise) -> String {
    let type =
      exercise.isAccessory
      ? StudentStrings.localized(.accessoryAccessory)
      : StudentStrings.localized(.accessoryMainLifts)
    let tags = StudentExerciseTag.rows.flatMap { $0 }.filter {
      ![.all, .squat, .bench, .deadlift].contains($0)
        && StudentExerciseTag.tags(for: exercise).contains($0)
    }.map(\.title)
    return ([type] + tags).joined(separator: " · ")
  }
}

/// Each semantic row wraps independently; no horizontal scrolling even at accessibility sizes.
private struct StudentTagLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(width: proposal.width ?? 320, subviews: subviews, origin: nil)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    _ = arrange(width: bounds.width, subviews: subviews, origin: bounds.origin)
  }

  private func arrange(width: CGFloat, subviews: Subviews, origin: CGPoint?) -> CGSize {
    let gap = MeetPRSpacing.space1
    var x: CGFloat = 0
    var y: CGFloat = 0
    var height: CGFloat = 0
    for view in subviews {
      let measured = view.sizeThatFits(.unspecified)
      let size = CGSize(width: min(width, measured.width), height: measured.height)
      if x > 0 && x + size.width > width {
        x = 0
        y += height + gap
        height = 0
      }
      if let origin {
        view.place(
          at: CGPoint(x: origin.x + x, y: origin.y + y),
          proposal: ProposedViewSize(width: size.width, height: size.height))
      }
      x += size.width + gap
      height = max(height, size.height)
    }
    return CGSize(width: width, height: y + height)
  }
}

extension StudentExerciseTag {
  var title: String {
    let key: StudentStrings.Key =
      switch self {
      case .all: .addedTagAll
      case .squat: .addedTagSquat
      case .bench: .addedTagBench
      case .deadlift: .addedTagDeadlift
      case .core: .addedTagCore
      case .other: .addedTagOther
      case .chest: .addedTagChest
      case .back: .addedTagBack
      case .shoulders: .addedTagShoulders
      case .biceps: .addedTagBiceps
      case .triceps: .addedTagTriceps
      case .traps: .addedTagTraps
      case .forearms: .addedTagForearms
      case .quads: .addedTagQuads
      case .glutes: .addedTagGlutes
      case .hamstrings: .addedTagHamstrings
      case .calves: .addedTagCalves
      case .adductors: .addedTagAdductors
      case .hips: .addedTagHips
      }
    return StudentStrings.localized(key)
  }
}
