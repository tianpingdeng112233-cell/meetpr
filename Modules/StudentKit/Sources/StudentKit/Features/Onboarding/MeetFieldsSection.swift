import CoreModels
import DesignSystem
import SwiftUI

struct MeetFieldsSection: View {
  @Binding var draft: OnboardingDraft
  var showsErrors = false
  @State private var federation: MeetFederation?
  @State private var selectedClass: String?
  @State private var tableSex: MeetSex = .male
  @State private var previousValue = ""

  private var allowsSexChoice: Bool { draft.gender != .male && draft.gender != .female }
  private var columns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: MeetPRSpacing.xs), count: 4)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      MeetDateField(value: $draft.competitionDate, showsErrors: showsErrors)
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        OnboardingFieldLabel(
          title: StudentStrings.localized(.meetFederation),
          isHighlighted: showsErrors && federation == nil)
        if !previousValue.isEmpty {
          Text(StudentStrings.replacing(.meetPrevious, values: [previousValue]))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        HStack(spacing: MeetPRSpacing.xs) {
          ForEach(MeetFederation.allCases, id: \.self) { item in
            StudentSelectionBlock(title: item.rawValue, isSelected: federation == item) {
              guard federation != item else { return }
              federation = item
              selectedClass = nil
              draft.targetWeightClass = ""
            }
          }
        }
      }
      if let federation {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          OnboardingFieldLabel(
            title: StudentStrings.localized(.meetWeightClass),
            isHighlighted: showsErrors && selectedClass == nil)
          if allowsSexChoice {
            Picker(
              StudentStrings.localized(.meetWeightClass),
              selection: Binding(
                get: { tableSex },
                set: {
                  tableSex = $0
                  selectedClass = nil
                  draft.targetWeightClass = ""
                }
              )
            ) {
              Text(StudentStrings.localized(.meetMen)).tag(MeetSex.male)
              Text(StudentStrings.localized(.meetWomen)).tag(MeetSex.female)
            }
            .pickerStyle(.segmented)
          }
          LazyVGrid(columns: columns, spacing: MeetPRSpacing.sm) {
            ForEach(federation.classes(for: tableSex), id: \.self) { value in
              StudentSelectionBlock(title: "\(value) kg", isSelected: selectedClass == value) {
                selectedClass = value
                draft.targetWeightClass =
                  MeetClass(federation: federation, weightClass: value)?.formatted ?? ""
              }
            }
          }
        }
      }
    }
    .onAppear(perform: restoreSelection)
  }

  private func restoreSelection() {
    let parsed = MeetClass.parse(draft.targetWeightClass)
    federation = parsed?.federation
    selectedClass = parsed?.weightClass
    previousValue = parsed == nil ? draft.targetWeightClass : ""
    if draft.gender == .female {
      tableSex = .female
    } else if draft.gender == .male {
      tableSex = .male
    } else if let parsed,
      parsed.federation.classes(for: .female).contains(parsed.weightClass),
      !parsed.federation.classes(for: .male).contains(parsed.weightClass)
    {
      tableSex = .female
    }
  }
}

private struct MeetDateField: View {
  @Binding var value: String?
  let showsErrors: Bool

  private var range: ClosedRange<Date> {
    let today = Calendar.current.startOfDay(for: Date())
    let upper = Calendar.current.date(byAdding: .year, value: 10, to: today) ?? today
    return today...upper
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: StudentStrings.localized(.step7ExtrasSection011),
        isHighlighted: showsErrors && value == nil)
      DatePicker(
        StudentStrings.localized(.step7ExtrasSection011),
        selection: DateOnly.binding($value, default: range.lowerBound),
        in: range,
        displayedComponents: .date
      )
      .labelsHidden()
      #if os(iOS)
        .datePickerStyle(.wheel)
      #endif
      .onAppear {
        if value == nil { value = DateOnly.string(from: range.lowerBound) }
      }
    }
  }
}
