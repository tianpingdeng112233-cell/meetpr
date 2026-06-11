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
    Card(accessibilityLabel: "新学员请求 \(item.displayName)") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        headlineRow

        if item.onboarding.completed {
          summaryLines
        } else {
          Text("资料未填写完成")
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
        StatusBadge(status: .overdue, title: "即将过期")
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
      parts.append("\(age) 岁")
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
          "想增强: "
            + CoachOnboardingDisplay.muscleGroupList(onboarding.muscleGroupsToStrengthen))
      }
      if let tier = onboarding.gymTier {
        summaryText(CoachOnboardingDisplay.gymTierText(tier))
      }
      if onboarding.isCompeting == true, let competitionDate = onboarding.competitionDate {
        summaryText("备赛: \(competitionDate)")
      }
      if let note = onboarding.noteToCoach {
        Text("备注: \(note)")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(2)
      }
      summaryText(
        onboarding.uploadCount > 0 ? "资料 \(onboarding.uploadCount) 份" : "无上传资料")
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
      SecondaryButton("查看完整资料") {
        onViewProfile()
      }
      Spacer()
      SecondaryButton("拒绝") {
        onReject()
      }
      PrimaryButton("接收") {
        onAccept()
      }
    }
  }
}
