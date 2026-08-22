import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct VideoSetInfoStatusView: View {
  let state: VideoSetInfoState

  @ViewBuilder
  var body: some View {
    switch state {
    case .loading:
      EmptyView()
    case .unlinked:
      statusRow(CoachVideoFeedbackStrings.setInfoUnavailable, isFailure: false)
    case .loaded(let info):
      VideoSetInfoCard(info: info)
    case .failed:
      statusRow(CoachVideoFeedbackStrings.setInfoLoadFailed, isFailure: true)
    }
  }

  private func statusRow(_ message: String, isFailure: Bool) -> some View {
    Text(message)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(isFailure ? Color.MeetPR.danger : Color.MeetPR.textDisabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
