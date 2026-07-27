import DesignSystem
import Foundation
import SwiftUI

enum RosterAttendanceBarTone: Equatable, Sendable {
  case empty
  case dim
  case medium
  case bright

  static func map(_ week: CoachStudentRecentWeek) -> Self {
    guard week.plannedDays > 0 else { return .empty }
    guard week.trainedDays > 0 else { return .dim }
    guard week.trainedDays < week.plannedDays else { return .bright }
    return .medium
  }
}

enum CompetitionCountdownText {
  static func make(
    competitionDate: String?,
    relativeTo now: Date,
    timeZone: TimeZone = .current
  ) -> String? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let competitionDate,
      let competitionDay = parseDateOnly(competitionDate, calendar: calendar)
    else {
      return nil
    }

    let today = calendar.startOfDay(for: now)
    let daysRemaining = calendar.dateComponents([.day], from: today, to: competitionDay).day
    guard let daysRemaining, daysRemaining >= 0 else { return nil }
    return "D-\(daysRemaining)"
  }

  private static func parseDateOnly(_ rawValue: String, calendar: Calendar) -> Date? {
    let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else {
      return nil
    }

    let components = DateComponents(
      calendar: calendar,
      timeZone: calendar.timeZone,
      year: year,
      month: month,
      day: day
    )
    guard let date = calendar.date(from: components) else { return nil }
    let resolved = calendar.dateComponents([.year, .month, .day], from: date)
    guard resolved.year == year, resolved.month == month, resolved.day == day else {
      return nil
    }
    return calendar.startOfDay(for: date)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct StudentCompetitionPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .overlay {
        Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .fixedSize()
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct StudentAttendanceMiniBars: View {
  let tones: [RosterAttendanceBarTone]

  var body: some View {
    HStack(alignment: .bottom, spacing: 3) {
      ForEach(tones.indices, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1)
          .fill(color(for: tones[index]))
          .frame(width: 4, height: 12)
      }
    }
    .frame(width: 30, height: 12, alignment: .trailing)
  }

  private func color(for tone: RosterAttendanceBarTone) -> Color {
    switch tone {
    case .empty: .clear
    case .dim: Color.MeetPR.fgTertiary
    case .medium: Color.MeetPR.fgSecondary
    case .bright: Color.MeetPR.fgPrimary
    }
  }
}
