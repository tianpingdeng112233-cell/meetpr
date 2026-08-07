#if os(iOS)
  import SwiftUI
  import UIKit

  /// Wraps the system video editor for trimming videos imported from Photos.
  /// The presenting cover and this representable share one `VideoTrimSession`.
  /// UIKit delegate completion, cover dismissal, and dismantling may all race;
  /// the session makes their cleanup idempotent.
  struct VideoTrimmerView: UIViewControllerRepresentable {
    let session: VideoTrimSession

    func makeUIViewController(context: Context) -> UIVideoEditorController {
      let editor = UIVideoEditorController()
      editor.videoPath = session.sourceURL.path
      editor.videoMaximumDuration = session.maxDurationSeconds
      editor.videoQuality = .typeHigh
      editor.delegate = context.coordinator
      return editor
    }

    func updateUIViewController(_ uiViewController: UIVideoEditorController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(session: session)
    }

    static func dismantleUIViewController(
      _ uiViewController: UIVideoEditorController,
      coordinator: Coordinator
    ) {
      uiViewController.delegate = nil
      coordinator.session.cancelled()
    }

    final class Coordinator: NSObject, UIVideoEditorControllerDelegate,
      UINavigationControllerDelegate
    {
      let session: VideoTrimSession

      init(session: VideoTrimSession) {
        self.session = session
      }

      func videoEditorController(
        _ editor: UIVideoEditorController,
        didSaveEditedVideoToPath editedVideoPath: String
      ) {
        session.saved(editedVideoPath: editedVideoPath)
      }

      func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        session.cancelled()
      }

      func videoEditorController(
        _ editor: UIVideoEditorController,
        didFailWithError error: any Error
      ) {
        session.failed()
      }
    }
  }
#endif
