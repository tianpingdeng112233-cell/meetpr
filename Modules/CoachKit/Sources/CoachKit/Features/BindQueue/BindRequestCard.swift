import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// One pending receive-queue card with the 9-item onboarding summary
/// (spec 033 §3). Falls back to the degraded layout (name + waiting time)
/// when the student never completed onboarding.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct BindRequestCard: View {
  let item: CoachBindRequestItem
  let now: Date
  let onViewProfile: () -> Void
  let onAccept: () -> Void
  let onReject: () -> Void

  var body: some View {
    Card(
      accessibilityLabel: CoachBindStrings.replacing(
        "coach.bind.card.accessibility", ["student": item.displayName])
    ) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        headlineRow

        if item.onboarding.completed {
          summaryLines
        } else {
          Text(CoachBindStrings.text("coach.bind.card.profileIncomplete"))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        waitingRow
        buttonRow
      }
    }
  }

  private var headlineRow: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(headlineText)
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(1)
      Spacer(minLength: MeetPRSpacing.sm)
      if CoachOnboardingDisplay.isExpiringSoon(expiredAt: item.expiredAt, now: now) {
        StatusBadge(status: .overdue, title: CoachBindStrings.text("coach.bind.card.expiring"))
      }
    }
  }

  private var headlineText: String {
    var parts = [item.displayName]
    let onboarding = item.onboarding
    if let gender = onboarding.gender {
      parts.append(CoachOnboardingDisplay.genderText(gender))
    }
    if let age = CoachOnboardingDisplay.age(birthDate: onboarding.birthDate, now: now) {
      parts.append(
        CoachLocalization.localized("coach.bind.card.age \(age)"))
    }
    if let weight = onboarding.weightKg {
      parts.append("\(CoachOnboardingDisplay.decimalText(weight)) kg")
    }
    return parts.joined(separator: " · ")
  }

  @ViewBuilder
  private var summaryLines: some View {
    let onboarding = item.onboarding
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      if let years = onboarding.trainingYears {
        summaryText(
          "\(CoachOnboardingDisplay.trainingYearsText(years)) / "
            + CoachOnboardingDisplay.oneRMTrio(
              squat: onboarding.squat1RMKg,
              bench: onboarding.bench1RMKg,
              deadlift: onboarding.deadlift1RMKg
            )
        )
      }
      if !onboarding.muscleGroupsToStrengthen.isEmpty {
        summaryText(
          CoachBindStrings.replacing(
            "coach.bind.card.strengthen",
            ["groups": CoachOnboardingDisplay.muscleGroupList(onboarding.muscleGroupsToStrengthen)]
          ))
      }
      if let tier = onboarding.gymTier {
        summaryText(CoachOnboardingDisplay.gymTierText(tier))
      }
      if onboarding.isCompeting == true, let competitionDate = onboarding.competitionDate {
        summaryText(
          CoachBindStrings.replacing(
            "coach.bind.card.competition", ["date": competitionDate]))
      }
      if let note = onboarding.noteToCoach {
        Text(CoachBindStrings.replacing("coach.bind.card.note", ["note": note]))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(2)
      }
      summaryText(
        onboarding.uploadCount > 0
          ? CoachLocalization.localized("coach.bind.card.uploadCount \(onboarding.uploadCount)")
          : CoachBindStrings.text("coach.bind.card.noUploads"))
    }
  }

  private func summaryText(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.fgSecondary)
  }

  private var waitingRow: some View {
    Text(CoachOnboardingDisplay.waitingText(since: item.submittedAt, now: now))
      .font(Font.MeetPR.caption)
      .foregroundStyle(Color.MeetPR.fgTertiary)
  }

  private var buttonRow: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      SecondaryButton(CoachBindStrings.text("coach.bind.card.viewProfile")) {
        onViewProfile()
      }
      Spacer()
      SecondaryButton(CoachBindStrings.text("coach.bind.card.reject")) {
        onReject()
      }
      PrimaryButton(CoachBindStrings.text("coach.bind.card.accept")) {
        onAccept()
      }
    }
  }
}
