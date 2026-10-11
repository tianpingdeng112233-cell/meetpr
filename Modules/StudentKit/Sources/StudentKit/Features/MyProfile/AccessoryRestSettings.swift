import DesignSystem
import SwiftUI

struct AccessoryRestSettings: View {
  @Binding var seconds: Int

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.localized(.accessoryExercises))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textMuted)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: MeetPRSpacing.space3) {
          AccessoryRestLabel()
          Spacer(minLength: MeetPRSpacing.space2)
          AccessoryRestStepper(seconds: $seconds)
        }
        VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
          AccessoryRestLabel()
          AccessoryRestStepper(seconds: $seconds)
        }
      }
      .padding(MeetPRSpacing.space4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    }
  }
}

private struct AccessoryRestLabel: View {
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(StudentStrings.localized(.accessoryRest))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(StudentStrings.localized(.accessoryRange))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct AccessoryRestStepper: View {
  @Binding var seconds: Int

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Button {
        seconds = max(30, seconds - 15)
      } label: {
        Image(systemName: "minus")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.surfaceRaised, in: .circle)
      }
      .disabled(seconds <= 30)
      .accessibilityLabel(StudentStrings.localized(.accessoryLess))
      Text(StudentRestTimerCopy.durationText(seconds))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
        .fixedSize()
        .accessibilityIdentifier("accessoryRest.duration")
      Button {
        seconds = min(300, seconds + 15)
      } label: {
        Image(systemName: "plus")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.surfaceRaised, in: .circle)
      }
      .disabled(seconds >= 300)
      .accessibilityLabel(StudentStrings.localized(.accessoryMore))
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.MeetPR.textPrimary)
  }
}
