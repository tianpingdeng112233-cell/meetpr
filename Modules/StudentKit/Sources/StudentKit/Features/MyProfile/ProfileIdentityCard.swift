import CoreModels
import DesignSystem
import SwiftUI

struct ProfileIdentityCard: View {
  let identity: ProfileIdentity
  let profile: OnboardingProfile?
  let blank: Bool
  let onOneRMInfo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      ProfileIdentityRow(identity: identity)
      Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
      Button(action: onOneRMInfo) {
        ProfileOneRMGrid(profile: profile, blank: blank)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        StudentStrings.replacing(
          .profileOneRMLabel, values: ProfileOneRMGrid.values(profile, blank: blank)))
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct ProfileIdentityRow: View {
  let identity: ProfileIdentity

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      ZStack {
        Circle().fill(Color.MeetPR.surfaceRaised)
        let initials = ProfileIdentity.initials(identity.name)
        if initials.isEmpty {
          Image(systemName: "person")
            .foregroundStyle(Color.MeetPR.textMuted)
        } else {
          Text(initials)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
      .frame(width: MeetPRSpacing.xxl, height: MeetPRSpacing.xxl)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(identity.name)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
        if let coach = identity.coach {
          Text(StudentStrings.replacing(.profileCoach, values: [coach]))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}

struct ProfileOneRMGrid: View {
  let profile: OnboardingProfile?
  let blank: Bool

  static func values(_ profile: OnboardingProfile?, blank: Bool) -> [String] {
    if blank { return Array(repeating: "", count: 4) }
    guard let profile else { return Array(repeating: "—", count: 4) }
    let presentation = MyProfileV3Presentation.make(
      profile: profile, readiness: nil, restTimer: .automatic)
    return (presentation.oneRepMaxima.map(\.kilograms) + [presentation.sbdTotalKg])
      .map { $0.map(UnitDisplay.plainString) ?? "—" }
  }

  var body: some View {
    let values = Self.values(profile, blank: blank)
    let labels = [
      LiftFamily.squat.studentDisplayName, StudentStrings.localized(.progressBench),
      LiftFamily.deadlift.studentDisplayName, StudentStrings.localized(.progressTotal),
    ]
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        HStack(alignment: .top, spacing: MeetPRSpacing.space2) {
          ForEach(labels.indices, id: \.self) { index in
            Text(labels[index])
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textMuted)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        ProfileOneRMNumbers(values: values)
      }
      Label(StudentStrings.localized(.profileLocked), systemImage: "lock")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .contentShape(.rect)
  }
}

/// Measure the unscaled numerals once so every column uses the same fitting font.
private struct ProfileOneRMNumbers: View {
  let values: [String]
  @State private var availableWidth: CGFloat = 0
  @State private var naturalWidth: CGFloat = 0

  var body: some View {
    let columnWidth = max(0, (availableWidth - 3 * MeetPRSpacing.space2) / 4)
    let scale = naturalWidth > 0 && columnWidth > 0 ? min(1, columnWidth / naturalWidth) : 1
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
      ForEach(values.indices, id: \.self) { index in
        Text(values[index])
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size22 * scale, weight: .bold))
          .foregroundStyle(index == 3 ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
          .fixedSize()
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      availableWidth = $0
    }
    .background {
      // Overlay the original strings to measure the widest at the current Dynamic Type size.
      ZStack {
        ForEach(values.indices, id: \.self) { index in
          Text(values[index])
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size22, weight: .bold))
            .fixedSize()
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.width
      } action: {
        naturalWidth = $0
      }
      .hidden()
      .accessibilityHidden(true)
    }
  }
}
