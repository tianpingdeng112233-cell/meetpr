import CoreModels
import DesignSystem
import SwiftUI

struct LoadTypePrescriptionHeader: View {
  let set: PrescribedSet
  let count: Int

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: MeetPRSpacing.space2) {
          Text(summary).font(.subheadline)
          LoadTypeBadge(isBodyweight: set.isBodyweight)
        }
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text(summary).font(.subheadline)
          LoadTypeBadge(isBodyweight: set.isBodyweight)
        }
      }
      Text(
        StudentStrings.localized(
          set.isBodyweight ? .loadTypeBodyweightHint : .loadTypeFreeWeightHint)
      )
      .font(.caption)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var summary: String {
    let reps = StudentFormatting.loadTypeReps(set)
    let target = set.intensity.map {
      StudentStrings.replacing(.loadTypeTarget, values: [StudentFormatting.intensityText($0)])
    }
    return ["\(count) × \(reps)", target].compactMap { $0 }.joined(separator: " · ")
  }
}

private struct LoadTypeBadge: View {
  let isBodyweight: Bool

  var body: some View {
    Text(StudentStrings.localized(isBodyweight ? .loadTypeBodyweight : .loadTypeFreeWeight))
      .font(.caption.bold())
      .foregroundStyle(isBodyweight ? Color.MeetPR.textSecondary : Color.MeetPR.goldText)
      .padding(.horizontal, MeetPRSpacing.space2)
      .padding(.vertical, MeetPRSpacing.space1)
      .background(
        isBodyweight ? Color.MeetPR.surfaceRaised : Color.MeetPR.goldRGB.opacity(0.15),
        in: .capsule)
  }
}
