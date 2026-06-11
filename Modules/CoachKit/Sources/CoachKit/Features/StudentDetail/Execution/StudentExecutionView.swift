import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentExecutionView: View {
  let days: [StudentExecutionDay]

  var body: some View {
    if days.isEmpty {
      ContentUnavailableView("暂无执行记录", systemImage: "list.bullet.rectangle")
        .background(Color.MeetPR.bg)
    } else {
      List {
        ForEach(days) { day in
          NavigationLink {
            CoachDayDetailView(day: day)
          } label: {
            StudentExecutionDayRow(day: day)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct StudentExecutionDayRow: View {
  let day: StudentExecutionDay

  var body: some View {
    HStack(spacing: MeetPRSpacing.base) {
      VStack(alignment: .leading, spacing: 2) {
        Text(CoachStudentFormatting.weekdayText(day.date))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(CoachStudentFormatting.shortDateText(day.date))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .frame(width: 58, alignment: .leading)

      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(title)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(day.completionText)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      Spacer()

      if day.completedSetCount > 0 {
        StatusBadge(status: day.completedSetCount >= day.plannedSetCount ? .completed : .live)
      }
    }
    .padding(.vertical, MeetPRSpacing.xs)
  }

  private var title: String {
    guard let exercises = day.planDay?.exercises, !exercises.isEmpty else {
      return day.logs.isEmpty ? "休息" : "自由记录"
    }
    return exercises.map(\.exercise.name).joined(separator: " / ")
  }
}
