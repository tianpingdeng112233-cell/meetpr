import DesignSystem
import SwiftUI

struct MeetWeightStrip: View {
  let model: BodyWeightEntryModel
  let onEditMeet: () -> Void
  @Environment(\.locale) private var locale
  @AppStorage private var settingOn: Bool

  init(studentID: UUID, model: BodyWeightEntryModel, onEditMeet: @escaping () -> Void) {
    self.model = model
    self.onEditMeet = onEditMeet
    _settingOn = AppStorage(
      wrappedValue: false, DailyBodyWeightPreference.key(studentID: studentID))
  }

  var body: some View {
    let presentation = MeetWeightStripPresentation(
      profile: model.profile, records: model.records, settingOn: settingOn)
    if presentation.isVisible {
      HStack(spacing: 0) {
        if let competitionText = presentation.competitionText(locale: locale) {
          Button(action: onEditMeet) {
            HStack(spacing: MeetPRSpacing.space2) {
              Image(systemName: "flag").font(.body)
              Text(competitionText)
                .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(.rect)
          }
          Rectangle().fill(Color.MeetPR.borderSubtle).frame(width: 1, height: 28)
        }
        Button(action: model.open) {
          HStack(spacing: MeetPRSpacing.space2) {
            Text(StudentStrings.localized(.weightTodayLabel))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textSecondary)
            Spacer(minLength: 0)
            if model.isPresented {
              Text(model.previewText + " kg").monospacedDigit().foregroundStyle(
                Color.MeetPR.goldText)
            } else if let kilograms = presentation.todayWeightKg {
              (Text(kilograms.formatted(.number.precision(.fractionLength(1)))).bold()
                + Text(" kg").font(.MeetPR.body(size: MeetPRFontMetrics.size12)))
                .monospacedDigit()
            } else {
              Text(StudentStrings.localized(.weightLogShort))
                .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
                .foregroundStyle(Color.MeetPR.goldText)
                .padding(.horizontal, MeetPRSpacing.space2)
                .frame(height: 30)
                .background(Color.MeetPR.goldText.opacity(0.12), in: .capsule)
            }
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
          .padding(.horizontal, MeetPRSpacing.space3)
          .frame(maxWidth: .infinity, minHeight: 48)
          .contentShape(.rect)
        }
        .accessibilityIdentifier("training.bodyWeight")
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14).stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
      }
      .accessibilityIdentifier("training.meetWeightStrip")
    }
  }
}
