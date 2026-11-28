import SwiftUI

/// The wordmark asset resolves its light or dark artwork from the current appearance.
@MainActor
public struct MeetPRMark: View {
  private let height: CGFloat

  public init(height: CGFloat) {
    self.height = height
  }

  public static var header: MeetPRMark {
    MeetPRMark(height: 18)
  }

  public var body: some View {
    Image("MeetPRMark", bundle: .module)
      .resizable()
      .scaledToFit()
      .frame(width: height * 2443 / 605, height: height)
      .accessibilityHidden(true)
  }
}

#Preview("MeetPRMark") {
  VStack(alignment: .leading) {
    MeetPRMark.header
    MeetPRMark(height: 23)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
}
