import DesignSystem
import SwiftUI

#Preview("SetEntry Video · Every State · Dark") {
  VideoAttachmentV3PreviewList()
    .preferredColorScheme(.dark)
}

#Preview("SetEntry Video · Every State · Light") {
  VideoAttachmentV3PreviewList()
    .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
private struct VideoAttachmentV3PreviewList: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      previewRow(.choices(cameraAvailable: true))
      previewRow(.choices(cameraAvailable: false))
      previewRow(.attached(cameraAvailable: true, canDelete: false, delivered: false))
      previewRow(.attached(cameraAvailable: true, canDelete: true, delivered: true))
      previewRow(.failed)
    }
    .padding()
    .background(Color.MeetPR.bgBase)
  }

  private func previewRow(_ state: VideoAttachmentV3State) -> some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Text("视频")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .medium))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      VideoAttachmentV3Controls(
        state: state,
        onCamera: {},
        onLibrary: {},
        onCancel: {},
        onRetry: {},
        onDelete: {}
      )
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point11)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}
