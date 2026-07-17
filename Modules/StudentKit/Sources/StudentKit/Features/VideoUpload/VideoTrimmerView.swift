#if os(iOS)
  import SwiftUI
  import UIKit

  /// Wraps the system video editor for trimming videos imported from Photos.
  /// Dismissal is owned solely by the presenting SwiftUI state: every callback
  /// clears the `fullScreenCover` item, which tears the editor down. The
  /// once-only + cleanup semantics live in `VideoTrimCompletion`.
  struct VideoTrimmerView: UIViewControllerRepresentable {
    let sourceURL: URL
    let maxDurationSeconds: TimeInterval
    let onSave: (URL) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> UIVideoEditorController {
      let editor = UIVideoEditorController()
      editor.videoPath = sourceURL.path
      editor.videoMaximumDuration = maxDurationSeconds
      editor.videoQuality = .typeHigh
      editor.delegate = context.coordinator
      return editor
    }

    func updateUIViewController(_ uiViewController: UIVideoEditorController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(
        completion: VideoTrimCompletion(sourceURL: sourceURL) { outcome in
          switch outcome {
          case .saved(let editedURL): onSave(editedURL)
          case .cancelled: onCancel()
          case .failed: onFailure()
          }
        }
      )
    }

    final class Coordinator: NSObject, UIVideoEditorControllerDelegate,
      UINavigationControllerDelegate
    {
      private let completion: VideoTrimCompletion

      init(completion: VideoTrimCompletion) {
        self.completion = completion
      }

      func videoEditorController(
        _ editor: UIVideoEditorController,
        didSaveEditedVideoToPath editedVideoPath: String
      ) {
        completion.saved(editedVideoPath: editedVideoPath)
      }

      func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        completion.cancelled()
      }

      func videoEditorController(
        _ editor: UIVideoEditorController,
        didFailWithError error: any Error
      ) {
        completion.failed()
      }
    }
  }
#endif
