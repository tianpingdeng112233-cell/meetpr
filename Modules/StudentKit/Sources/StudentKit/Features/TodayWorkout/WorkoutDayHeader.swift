import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct WorkoutDayHeader: View {
  let day: StudentPlanDay
  let context: TodayWorkoutPlanContext?
  let readinessFiled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(.title2.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        readinessBadge
      }

      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      if !metadataBadges.isEmpty {
        LazyVGrid(columns: badgeColumns, alignment: .leading, spacing: 6) {
          ForEach(metadataBadges) { badge in
            metadataBadge(badge)
          }
        }
        .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var badgeColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 112), spacing: 6, alignment: .leading)]
  }

  private var metadataBadges: [PlanAlgorithmMetadata.Badge] {
    context?.algorithmMetadata.badges() ?? []
  }

  private var title: String {
    var parts = [
      context?.planKind.displayName ?? PlanKind.regular.displayName,
      "第\(context?.weekIndex ?? 1)周",
      StudentFormatting.weekdayFormatter.string(from: day.date),
    ]
    if let mainLiftDay {
      parts.append(mainLiftDay)
    }
    return parts.joined(separator: " · ")
  }

  private var subtitle: String {
    StudentFormatting.dayMonthFormatter.string(from: day.date)
  }

  private var mainLiftDay: String? {
    guard let exercise = day.exercises.first(where: { $0.exercise.isMainLift })?.exercise else {
      return nil
    }
    return "\(Self.simplifiedExerciseName(exercise.name))日"
  }

  private var readinessBadge: some View {
    Label(readinessFiled ? "已签到" : "未签到", systemImage: readinessFiled ? "checkmark" : "heart")
      .font(.caption)
      .foregroundStyle(readinessFiled ? Color.MeetPR.green : Color.MeetPR.fgTertiary)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(readinessFiled ? Color.MeetPR.greenSoft : Color.MeetPR.surface2)
      .clipShape(.capsule)
  }

  private func metadataBadge(_ badge: PlanAlgorithmMetadata.Badge) -> some View {
    Text(badge.title)
      .font(.caption2)
      .foregroundStyle(badge.tone == .stale ? Color.MeetPR.fgTertiary : Color.MeetPR.fgSecondary)
      .lineLimit(2)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(badge.tone == .stale ? Color.MeetPR.surface2 : Color.MeetPR.greenSoft)
      .clipShape(.capsule)
  }

  private static func simplifiedExerciseName(_ name: String) -> String {
    let withoutChineseParen = name.split(separator: "（", maxSplits: 1).first.map(String.init)
    let withoutAsciiParen = withoutChineseParen?
      .split(separator: "(", maxSplits: 1)
      .first
      .map(String.init)
    return withoutAsciiParen?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
  }
}

extension PlanKind {
  fileprivate var displayName: String {
    switch self {
    case .regular:
      "力量块"
    case .adaptation:
      "适应周"
    }
  }
}

extension Exercise {
  fileprivate var isMainLift: Bool {
    exerciseType == .mainLift || exerciseType == .mainLiftVariation || mainLiftFamily != nil
  }
}
