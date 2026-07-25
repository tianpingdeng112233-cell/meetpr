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
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack(spacing: MeetPRSpacing.space2) {
        Text(exercise.rawName)
          .font(.subheadline.bold())
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        statusBadge
      }

      if let boundName {
        Text("已绑定：\(boundName)")
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }

      if exercise.boundExerciseID == nil {
        if candidates.isEmpty {
          Text("库里没有相近动作——本组导入需要先在库里有它。")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MeetPRSpacing.space2) {
              ForEach(candidates) { candidate in
                Button {
                  exercise.boundExerciseID = candidate.id
                  exercise.isMainLift = candidate.mainLiftFamily != nil
                } label: {
                  Text(candidate.name)
                    .font(.caption.bold())
                    .padding(.horizontal, MeetPRSpacing.point10)
                    .padding(.vertical, MeetPRSpacing.point6)
                    .background(Color.MeetPR.surfaceElevated)
                    .clipShape(.capsule)
                }
                .buttonStyle(PressScaleButtonStyle())
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
        badge("可发布", color: Color.MeetPR.success, soft: Color.MeetPR.successSoft)
      } else if exercise.boundExerciseID == nil {
        badge("待绑定", color: Color.MeetPR.gold500, soft: Color.MeetPR.goldSoft)
      } else {
        badge("待补值", color: Color.MeetPR.gold500, soft: Color.MeetPR.goldSoft)
      }
    }
  }

  private func badge(_ text: String, color: Color, soft: Color) -> some View {
    Text(text)
      .font(.caption2.bold())
      .foregroundStyle(color)
      .padding(.horizontal, MeetPRSpacing.point6)
      .padding(.vertical, MeetPRSpacing.point2)
      .background(soft)
      .clipShape(.capsule)
  }
}
