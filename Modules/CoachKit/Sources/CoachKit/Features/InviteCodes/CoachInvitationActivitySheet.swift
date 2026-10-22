#if os(iOS)
  import SwiftUI
  import UIKit

  struct CoachInvitationActivitySheet: UIViewControllerRepresentable {
    let code: String
    let coachName: String?
    let onDismiss: @MainActor @Sendable () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
      let controller = UIActivityViewController(
        activityItems: [CoachInvitationActivityItemSource(code: code, coachName: coachName)],
        applicationActivities: nil)
      controller.completionWithItemsHandler = { [onDismiss] _, _, _, _ in
        Task { @MainActor in
          onDismiss()
        }
      }
      return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
#endif
