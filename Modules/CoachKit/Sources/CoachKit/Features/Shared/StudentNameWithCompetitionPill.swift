import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct StudentNameWithCompetitionPill: View {
  let displayName: String
  let competitionCountdownText: String?
  let font: Font
  let minimumScaleFactor: CGFloat

  var body: some View {
    if let competitionCountdownText {
      // The pill is optional adornment: the preferred candidate requires the
      // full intrinsic name, and the fallback drops the pill before SwiftUI
      // may compress or truncate the name.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 6) {
          Text(displayName)
            .font(font)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
          StudentCompetitionPill(text: competitionCountdownText)
        }

        Text(displayName)
          .font(font)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
          .minimumScaleFactor(minimumScaleFactor)
      }
    } else {
      Text(displayName)
        .font(font)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(1)
        .minimumScaleFactor(minimumScaleFactor)
    }
  }
}
