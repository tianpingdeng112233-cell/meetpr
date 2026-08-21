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
      .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
      .foregroundStyle(isHighlighted ? Color.MeetPR.dangerMuted : Color.MeetPR.textPrimary)
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
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
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
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
        .foregroundStyle(isSelected ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.md)
        .background(
          isSelected ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
        )
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(
              isSelected ? Color.MeetPR.goldRGB.opacity(0.4) : Color.MeetPR.borderDefault,
              lineWidth: 1
            )
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
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
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
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(isSelected ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
          isSelected ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
        )
        .overlay {
          Capsule().stroke(
            isSelected ? Color.MeetPR.goldRGB.opacity(0.4) : Color.MeetPR.borderDefault,
            lineWidth: 1
          )
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
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textSecondary)
      if let footnote {
        Text(footnote)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }

  private var currentLabel: String {
    guard let notch else { return StudentStrings.localized(.onboardingFieldComponents001) }
    return OnboardingLabels.scaleLabel(labels, notch: notch)
  }

  private func notchButton(_ value: Int) -> some View {
    let isSelected = notch == value
    return Button {
      notch = value
    } label: {
      Text("\(value)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(isSelected ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(
          isSelected ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
        )
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.sm)
            .stroke(
              isSelected ? Color.MeetPR.goldRGB.opacity(0.4) : Color.MeetPR.borderDefault,
              lineWidth: 1
            )
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
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(MeetPRSpacing.md)
          .frame(minHeight: 44)
          .background(Color.MeetPR.surfaceCard)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .stroke(
                isHighlighted ? Color.MeetPR.danger : Color.MeetPR.borderDefault,
                lineWidth: 1
              )
          }
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          #if os(iOS)
            .keyboardType(.decimalPad)
          #endif
          .onChange(of: text) { _, newValue in
            onCommit(newValue)
          }
        Text(unitSuffix)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
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
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .scrollContentBackground(.hidden)
        .padding(MeetPRSpacing.sm)
        .frame(minHeight: 88)
        .background(Color.MeetPR.surfaceCard)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text(placeholder)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
              .foregroundStyle(Color.MeetPR.textMuted)
              .padding(MeetPRSpacing.md)
              .allowsHitTesting(false)
          }
        }
    }
  }
}
