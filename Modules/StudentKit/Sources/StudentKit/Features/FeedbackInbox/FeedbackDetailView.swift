import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct FeedbackDetailView: View {
  let item: CoachFeedback

  public init(item: CoachFeedback) {
    self.item = item
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          Image(systemName: "person.crop.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.MeetPR.brandRed)
          VStack(alignment: .leading, spacing: 2) {
            Text("教练反馈")
              .font(.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
              .font(.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }

        if let dayDate = item.dayDate {
          Label(
            "关联训练日 " + StudentFormatting.dayMonthFormatter.string(from: dayDate),
            systemImage: "calendar"
          )
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        Text(item.text)
          .font(.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color.MeetPR.surface1)
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.MeetPR.border, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: 12))
      }
      .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .navigationTitle("反馈")
  }
}
