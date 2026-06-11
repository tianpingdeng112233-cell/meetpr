import CoreModels
import DesignSystem
import SwiftUI

// Shared form primitives for the onboarding wizard steps AND the nine-card
// edit pages (spec 032 §7: same source so wizard and archive never drift).
// Deliberately not a form framework — one struct per control (risk 10).

/// Field label + optional 422-highlight ring (D12).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingFieldLabel: View {
  let title: String
  var isHighlighted = false

  var body: some View {
    Text(title)
      .font(Font.MeetPR.bodyEmphasis)
      .foregroundStyle(isHighlighted ? Color.MeetPR.brandRed : Color.MeetPR.fgPrimary)
  }
}

/// Single-choice option cards (高杠/低杠, gym tier, ...).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingChoiceCards<Value: Hashable>: View {
  let title: String
  let options: [(value: Value, label: String)]
  @Binding var selection: Value?
  var isHighlighted = false
  var subtitle: String?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: title, isHighlighted: isHighlighted)
      if let subtitle {
        Text(subtitle)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      HStack(spacing: MeetPRSpacing.sm) {
        ForEach(options, id: \.value) { option in
          choiceCard(option.value, option.label)
        }
      }
    }
  }

  private func choiceCard(_ value: Value, _ label: String) -> some View {
    let isSelected = selection == value
    return Button {
      selection = value
    } label: {
      Text(label)
        .font(Font.MeetPR.body)
        .foregroundStyle(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.md)
        .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface1)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(
              isSelected ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
  }
}

/// Multi-select chips (training days, injury areas, muscle groups).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingChipGrid<Value: Hashable>: View {
  let title: String
  let options: [(value: Value, label: String)]
  @Binding var selection: [Value]
  /// nil = unlimited.
  var maxSelection: Int?
  var isHighlighted = false
  var footer: String?

  private let columns = [GridItem(.adaptive(minimum: 96), spacing: MeetPRSpacing.sm)]

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: title, isHighlighted: isHighlighted)
      LazyVGrid(columns: columns, alignment: .leading, spacing: MeetPRSpacing.sm) {
        ForEach(options, id: \.value) { option in
          chip(option.value, option.label)
        }
      }
      if let footer {
        Text(footer)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }

  private func chip(_ value: Value, _ label: String) -> some View {
    let isSelected = selection.contains(value)
    let isAtLimit = maxSelection.map { selection.count >= $0 } ?? false
    return Button {
      if isSelected {
        selection.removeAll { $0 == value }
      } else if !isAtLimit {
        selection.append(value)
      }
    } label: {
      Text(label)
        .font(Font.MeetPR.caption)
        .foregroundStyle(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface1)
        .overlay {
          Capsule().stroke(
            isSelected ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(Capsule())
        .opacity(!isSelected && isAtLimit ? 0.4 : 1)
    }
    .buttonStyle(.plain)
  }
}

/// 1-5 notch selector with wiki labels (Step 5 recovery scales, D8: the
/// wire carries the notch, the label is display-only).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingScalePicker: View {
  let title: String
  let labels: [String]
  @Binding var notch: Int?
  var isHighlighted = false
  var footnote: String?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: title, isHighlighted: isHighlighted)
      HStack(spacing: MeetPRSpacing.xs) {
        ForEach(1...labels.count, id: \.self) { value in
          notchButton(value)
        }
      }
      Text(currentLabel)
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      if let footnote {
        Text(footnote)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }

  private var currentLabel: String {
    guard let notch else { return "请选择" }
    return OnboardingLabels.scaleLabel(labels, notch: notch)
  }

  private func notchButton(_ value: Int) -> some View {
    let isSelected = notch == value
    return Button {
      notch = value
    } label: {
      Text("\(value)")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface1)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.sm)
            .stroke(
              isSelected ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
    }
    .buttonStyle(.plain)
  }
}

/// Numeric entry with unit suffix; parses on every edit through the given
/// parser so the draft only ever holds wire-legal metric values (D1).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingNumberField: View {
  let title: String
  let unitSuffix: String
  @Binding var text: String
  let onCommit: (String) -> Void
  var isHighlighted = false
  var placeholder = ""

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: title, isHighlighted: isHighlighted)
      HStack(spacing: MeetPRSpacing.sm) {
        TextField(placeholder, text: $text)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .padding(MeetPRSpacing.md)
          .frame(minHeight: 44)
          .background(Color.MeetPR.surface1)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .stroke(
                isHighlighted ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          #if os(iOS)
            .keyboardType(.decimalPad)
          #endif
          .onChange(of: text) { _, newValue in
            onCommit(newValue)
          }
        Text(unitSuffix)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
  }
}

/// Multi-line free text (injury notes / note to coach).
@available(iOS 17.0, macOS 14.0, *)
struct OnboardingTextEditor: View {
  let title: String
  @Binding var text: String
  var placeholder = ""

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(title: title)
      TextEditor(text: $text)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .scrollContentBackground(.hidden)
        .padding(MeetPRSpacing.sm)
        .frame(minHeight: 88)
        .background(Color.MeetPR.surface1)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text(placeholder)
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgTertiary)
              .padding(MeetPRSpacing.md)
              .allowsHitTesting(false)
          }
        }
    }
  }
}
