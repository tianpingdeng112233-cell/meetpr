import CoreModels
import DesignSystem
import SwiftUI

/// Exercise binding for one parsed exercise (spec 043 §E4): an exact 折叠 match
/// auto-binds; otherwise the coach picks a catalog candidate. V1 offers no
/// custom-exercise creation — only bind-from-library.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseMatchSection: View {
  @Binding var exercise: ImportReviewExercise
  let candidates: [Exercise]
  let boundName: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(exercise.rawName)
          .font(.subheadline.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        statusBadge
      }

      if let boundName {
        Text(CoachImportStrings.boundTo(boundName))
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      if exercise.boundExerciseID == nil {
        if candidates.isEmpty {
          Text(CoachImportStrings.noSimilarExercise)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(candidates) { candidate in
                Button {
                  exercise.boundExerciseID = candidate.id
                  exercise.isMainLift = candidate.mainLiftFamily != nil
                } label: {
                  Text(CoachLocalization.exerciseName(candidate))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.MeetPR.surface2)
                    .clipShape(.capsule)
                }
              }
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var statusBadge: some View {
    Group {
      if ImportCompleteness.isComplete(exercise) {
        badge(
          CoachImportStrings.publishable, color: Color.MeetPR.green, soft: Color.MeetPR.greenSoft)
      } else if exercise.boundExerciseID == nil {
        badge(
          CoachImportStrings.needsBinding, color: Color.MeetPR.amber, soft: Color.MeetPR.amberSoft)
      } else {
        badge(
          CoachImportStrings.needsValues, color: Color.MeetPR.amber, soft: Color.MeetPR.amberSoft)
      }
    }
  }

  private func badge(_ text: String, color: Color, soft: Color) -> some View {
    Text(text)
      .font(.caption2.bold())
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(soft)
      .clipShape(.capsule)
  }
}
