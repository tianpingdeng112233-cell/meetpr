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
  @State private var text = ""

  private var isInvalid: Bool {
    isHighlighted || (!text.isEmpty && kilograms == nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: StudentStrings.localized(labelKey), isHighlighted: isInvalid)
      HStack(spacing: MeetPRSpacing.sm) {
        TextField("", text: input)
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
          #if os(iOS)
            .keyboardType(.decimalPad)
          #endif
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
    .onAppear(perform: syncText)
    .onChange(of: unit) { _, _ in syncText() }
    .onChange(of: text) { _, value in
      let filtered = BodyWeightInput.filtered(value, locale: locale)
      if value != filtered { text = filtered }
    }
  }

  private var input: Binding<String> {
    Binding(
      get: { text },
      set: {
        text = $0
        kilograms = BodyWeightInput.kilograms(
          BodyWeightInput.filtered($0, locale: locale), unit: unit, locale: locale)
      }
    )
  }

  private func syncText() {
    text = BodyWeightInput.text(kg: kilograms, unit: unit, locale: locale)
  }
}
