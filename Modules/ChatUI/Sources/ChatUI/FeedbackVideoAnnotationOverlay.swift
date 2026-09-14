import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoAnnotationOverlay: View {
  let url: URL
  let close: () -> Void
  let loadFailed: () -> Void

  var body: some View {
    Button(action: close) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .empty:
          ProgressView()
            .tint(.white)
            .accessibilityLabel(ChatStrings.refreshing)
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure:
          Color.clear
            .task(id: url) {
              loadFailed()
            }
        @unknown default:
          Color.clear
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
      .contentShape(.rect)
    }
    .accessibilityLabel(ChatStrings.closeAnnotation)
    .accessibilityIdentifier("feedback.video.annotationOverlay")
  }
}
