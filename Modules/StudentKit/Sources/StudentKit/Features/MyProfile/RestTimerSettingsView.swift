import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RestTimerSettingsView: View {
  @Binding var preference: StudentRestTimerPreference
  @State private var expandedBand: RestTimerBand?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space5) {
        RestTimerModeCard(selection: modeBinding)

        if case .custom = preference {
          VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
            RestTimerSectionTitle(StudentStrings.localized(.restTimerSettingsView001))
            VStack(spacing: 0) {
              ForEach(RestTimerBand.allCases) { band in
                RestTimerDurationRow(
                  band: band,
                  selection: secondsBinding(for: band),
                  isExpanded: expandedBand == band,
                  onToggle: { toggle(band) }
                )
                if band != RestTimerBand.allCases.last {
                  Rectangle()
                    .fill(Color.MeetPR.borderSubtle)
                    .frame(height: 1)
                }
              }
            }
            .background(Color.MeetPR.surfaceCard)
            .clipShape(.rect(cornerRadius: MeetPRRadius.card))
          }
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          RestTimerSectionTitle(StudentStrings.localized(.restTimerSettingsView002))
          RestTimerAutomaticRulesCard()
        }

        Text(StudentStrings.localized(.restTimerSettingsView003))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, MeetPRSpacing.space1)
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.top, MeetPRSpacing.space4)
      .padding(.bottom, MeetPRSpacing.point32)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentStrings.localized(.restTimerSettingsView004))
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(Color.MeetPR.bgBase, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
    #endif
  }

  private var modeBinding: Binding<RestTimerPreferenceMode> {
    Binding(
      get: {
        if case .automatic = preference { return .automatic }
        return .custom
      },
      set: { mode in
        preference = mode == .automatic ? .automatic : .defaultCustom
        expandedBand = nil
      }
    )
  }

  private func secondsBinding(for band: RestTimerBand) -> Binding<Int> {
    Binding(
      get: {
        let seconds = preference.customSeconds
        switch band {
        case .low:
          return seconds?.low ?? StudentRestTimerPreference.defaultLowSeconds
        case .mid:
          return seconds?.mid ?? StudentRestTimerPreference.defaultMidSeconds
        case .high:
          return seconds?.high ?? StudentRestTimerPreference.defaultHighSeconds
        }
      },
      set: { newValue in
        let seconds =
          preference.customSeconds
          ?? StudentRestTimerDurations(
            low: StudentRestTimerPreference.defaultLowSeconds,
            mid: StudentRestTimerPreference.defaultMidSeconds,
            high: StudentRestTimerPreference.defaultHighSeconds
          )
        switch band {
        case .low:
          preference = .custom(
            lowSeconds: newValue,
            midSeconds: seconds.mid,
            highSeconds: seconds.high
          )
        case .mid:
          preference = .custom(
            lowSeconds: seconds.low,
            midSeconds: newValue,
            highSeconds: seconds.high
          )
        case .high:
          preference = .custom(
            lowSeconds: seconds.low,
            midSeconds: seconds.mid,
            highSeconds: newValue
          )
        }
      }
    )
  }

  private func toggle(_ band: RestTimerBand) {
    expandedBand = expandedBand == band ? nil : band
  }
}

private enum RestTimerPreferenceMode: Hashable {
  case automatic
  case custom
}

private enum RestTimerBand: String, CaseIterable, Identifiable {
  case low
  case mid
  case high

  var id: Self { self }

  var title: String {
    switch self {
    case .low:
      StudentStrings.localized(.restTimerSettingsView005)
    case .mid:
      StudentStrings.localized(.restTimerSettingsView006)
    case .high:
      StudentStrings.localized(.restTimerSettingsView007)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct RestTimerModeCard: View {
  @Binding var selection: RestTimerPreferenceMode

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      RestTimerSectionTitle(StudentStrings.localized(.restTimerSettingsView008))
      Picker(StudentStrings.localized(.restTimerSettingsView008), selection: $selection) {
        Text(StudentRestTimerCopy.automaticModeTitle)
          .tag(RestTimerPreferenceMode.automatic)
        Text(StudentRestTimerCopy.customModeTitle)
          .tag(RestTimerPreferenceMode.custom)
      }
      .pickerStyle(.segmented)
      .tint(Color.MeetPR.gold500)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct RestTimerDurationRow: View {
  let band: RestTimerBand
  @Binding var selection: Int
  let isExpanded: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Button(action: onToggle) {
        HStack(spacing: MeetPRSpacing.space3) {
          Text(band.title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          Text(StudentRestTimerCopy.durationText(selection))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)
          Image(systemName: "chevron.down")
            .font(.system(size: MeetPRFontMetrics.size12, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textDim)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, MeetPRSpacing.space4)
        .frame(minHeight: MeetPRSpacing.point56)
        .contentShape(Rectangle())
      }
      .accessibilityLabel(
        StudentStrings.commaSeparated([
          band.title,
          StudentRestTimerCopy.durationText(selection),
        ])
      )
      .accessibilityHint(
        isExpanded
          ? StudentStrings.localized(.restTimerSettingsView009)
          : StudentStrings.localized(.restTimerSettingsView010))

      if isExpanded {
        Picker(band.title, selection: $selection) {
          ForEach(Self.durationOptions, id: \.self) { seconds in
            Text(StudentRestTimerCopy.durationText(seconds)).tag(seconds)
          }
        }
        #if os(iOS)
          .pickerStyle(.wheel)
        #else
          .pickerStyle(.menu)
        #endif
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color.MeetPR.surfaceRaised)
      }
    }
  }

  private static let durationOptions = Array(
    stride(
      from: StudentRestTimerPreference.durationRange.lowerBound,
      through: StudentRestTimerPreference.durationRange.upperBound,
      by: StudentRestTimerPreference.durationStep
    )
  )
}

@available(iOS 17.0, macOS 14.0, *)
private struct RestTimerAutomaticRulesCard: View {
  var body: some View {
    VStack(spacing: 0) {
      RestTimerRuleRow(
        title: StudentStrings.localized(.restTimerSettingsView005),
        value: StudentStrings.localized(.restTimerSettingsView011))
      Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
      RestTimerRuleRow(
        title: StudentStrings.localized(.restTimerSettingsView006),
        value: StudentStrings.localized(.restTimerSettingsView012))
      Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
      RestTimerRuleRow(
        title: StudentStrings.localized(.restTimerSettingsView007),
        value: StudentStrings.localized(.restTimerSettingsView013))
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct RestTimerRuleRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .medium))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Spacer()
      Text(value)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .frame(minHeight: MeetPRSpacing.point52)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct RestTimerSectionTitle: View {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
      .tracking(0.44)
      .foregroundStyle(Color.MeetPR.textMuted)
  }
}
