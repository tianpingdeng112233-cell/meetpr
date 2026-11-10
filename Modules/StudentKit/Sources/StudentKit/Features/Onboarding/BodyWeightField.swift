import CoreModels
import DesignSystem
import SwiftUI

struct BodyWeightField: View {
  @Binding var kilograms: Decimal?
  let unit: UnitPreference
  var labelKey: StudentStrings.Key = .step1BasicsSection003
  var isHighlighted = false
  var showsHelp = false
  @Environment(\.locale) private var locale
  @State private var showsNumberPad = false

  private var isInvalid: Bool {
    isHighlighted
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: StudentStrings.localized(labelKey), isHighlighted: isInvalid)
      HStack(spacing: MeetPRSpacing.sm) {
        Button {
          showsNumberPad = true
        } label: {
          Text(BodyWeightInput.text(kg: kilograms, unit: unit, locale: locale))
            .frame(
              maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget, alignment: .leading
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .padding(MeetPRSpacing.md)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.control))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(isInvalid ? Color.MeetPR.danger : Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .accessibilityLabel(StudentStrings.localized(labelKey))

        Text(UnitDisplay.weightUnitSuffix(unit))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      if showsHelp {
        Text(StudentStrings.localized(.bodyWeightPrecision))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .sheet(isPresented: $showsNumberPad) {
      BodyWeightNumberPad(
        initialText: BodyWeightEntryModel.inputText(kilograms),
        onChange: { _ in },
        onSave: { text in
          guard let value = BodyWeightEntryModel.kilograms(text) else { return }
          kilograms = value
          showsNumberPad = false
        },
        onCancel: { showsNumberPad = false }
      )
      .presentationDetents([.height(450)])
    }
  }
}
