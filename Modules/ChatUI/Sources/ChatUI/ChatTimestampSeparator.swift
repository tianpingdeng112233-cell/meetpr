import DesignSystem
import SwiftUI

public struct ChatTimestampSeparator: View {
  let text: String

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    Text(text)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textDim)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity)
      .padding(.bottom, MeetPRSpacing.space1)
  }
}
