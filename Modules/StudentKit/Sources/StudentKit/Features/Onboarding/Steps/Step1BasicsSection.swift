import CoreModels
import DesignSystem
import SwiftUI

/// Step 1 基础信息: unit preference, gender, birth date, height, weight.
/// Shared by the wizard and the 基础信息 card edit (spec 032 §7).
@available(iOS 17.0, macOS 14.0, *)
struct Step1BasicsSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []
  @State private var heightText = ""
  @State private var weightText = ""

  private var unit: UnitPreference { draft.unitPreference ?? .kg }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      unitPicker
      OnboardingChoiceCards(
        title: "性别",
        options: Gender.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.gender,
        isHighlighted: highlighted.contains("gender")
      )
      birthDatePicker
      OnboardingNumberField(
        title: "身高",
        unitSuffix: UnitDisplay.heightUnitSuffix(unit),
        text: $heightText,
        onCommit: { draft.heightCm = UnitDisplay.parseHeight($0, unit: unit) },
        isHighlighted: highlighted.contains("height_cm"),
        placeholder: unit == .kg ? "178" : "70"
      )
      OnboardingNumberField(
        title: "体重",
        unitSuffix: UnitDisplay.weightUnitSuffix(unit),
        text: $weightText,
        onCommit: { draft.weightKg = UnitDisplay.parseWeight($0, unit: unit) },
        isHighlighted: highlighted.contains("weight_kg"),
        placeholder: unit == .kg ? "83" : "183"
      )
    }
    .onAppear {
      syncTexts()
      // Visible defaults count as the selection (wiki v2.4): the wheel
      // shows 2000-01-01 and the segmented control shows 公斤·厘米, so
      // both must land in the draft or step 1 never unlocks 下一步.
      if draft.birthDate == nil {
        draft.birthDate = "2000-01-01"
      }
      if draft.unitPreference == nil {
        draft.unitPreference = .kg
      }
    }
  }

  private var unitPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: "单位制", isHighlighted: highlighted.contains("unit_preference"))
      Picker("单位制", selection: unitSelection) {
        Text("公斤 · 厘米").tag(UnitPreference.kg)
        Text("磅 · 英寸").tag(UnitPreference.lb)
      }
      .pickerStyle(.segmented)
    }
  }

  /// Switching units re-renders already-typed values in the new unit; the
  /// stored metric values never change (D1: the lens, not the data).
  private var unitSelection: Binding<UnitPreference> {
    Binding(
      get: { unit },
      set: { newUnit in
        guard newUnit != draft.unitPreference else { return }
        draft.unitPreference = newUnit
        syncTexts()
      }
    )
  }

  private var birthDatePicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: "生日", isHighlighted: highlighted.contains("birth_date"))
      DatePicker(
        "生日",
        selection: DateOnly.binding(
          $draft.birthDate, default: DateOnly.date(from: "2000-01-01") ?? Date()),
        in: birthDateRange,
        displayedComponents: .date
      )
      .labelsHidden()
      #if os(iOS)
        .datePickerStyle(.wheel)
      #endif
    }
  }

  private var birthDateRange: ClosedRange<Date> {
    let calendar = Calendar(identifier: .iso8601)
    let lower = calendar.date(from: DateComponents(year: 1930, month: 1, day: 1)) ?? .distantPast
    return lower...Date()
  }

  private func syncTexts() {
    heightText = UnitDisplay.heightText(cm: draft.heightCm, unit: unit)
    weightText = UnitDisplay.weightText(kg: draft.weightKg, unit: unit)
  }
}
