import CoreModels
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DayCard: View {
  let day: StudentPlanDay
  let logs: [StudentSetLog]

  var body: some View {
    let progress = StudentFormatting.completedCount(for: day, logs: logs)

    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(StudentFormatting.dayMonthFormatter.string(from: day.date))
          .font(.headline)
        Text(StudentFormatting.weekdayFormatter.string(from: day.date))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if day.exercises.isEmpty {
        Text("休息日")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        Text("\(progress.completed)/\(progress.total) 组")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(progress.completed == progress.total ? .green : .orange)
      }
    }
    .padding(.vertical, 6)
  }
}
