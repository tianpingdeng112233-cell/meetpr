import DesignSystem
import SwiftUI

struct LoadTypeWeightInput: View {
  @Binding var text: String
  let isBodyweight: Bool
  let invalid: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(
        StudentStrings.localized(isBodyweight ? .loadTypeOptionalWeight : .loadTypeRequiredWeight)
      )
      .font(.caption)
      .foregroundStyle(invalid ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
      TextField(
        isBodyweight ? "0" : StudentStrings.localized(.loadTypeRequiredPlaceholder),
        text: $text
      )
      .textFieldStyle(.plain)
      .font(.body.monospacedDigit())
      .padding(MeetPRSpacing.space3)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.inset))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .strokeBorder(invalid ? Color.MeetPR.danger : Color.MeetPR.borderStrong)
      }
      .accessibilityIdentifier("setEntry.loadType.weight")
      #if os(iOS)
        .keyboardType(.decimalPad)
      #endif
    }
  }
}
