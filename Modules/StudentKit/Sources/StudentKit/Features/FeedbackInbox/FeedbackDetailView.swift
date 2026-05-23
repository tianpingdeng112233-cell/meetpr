import CoreModels
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
        if let dayDate = item.dayDate {
          Label(StudentFormatting.dayMonthFormatter.string(from: dayDate), systemImage: "calendar")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Text(item.text)
          .font(.body)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding()
    }
    .navigationTitle("反馈")
  }
}
