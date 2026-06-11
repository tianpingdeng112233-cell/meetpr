#if os(iOS)
  import SwiftUI
  import UIKit
  import UniformTypeIdentifiers

  /// UIImagePickerController wrapper for in-app video capture (spec 027).
  /// Caps recording at `maxDurationSeconds` — the picker stops automatically.
  struct CameraVideoPicker: UIViewControllerRepresentable {
    let maxDurationSeconds: TimeInterval
    let onPicked: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = [UTType.movie.identifier]
      picker.cameraCaptureMode = .video
      picker.videoMaximumDuration = maxDurationSeconds
      picker.videoQuality = .typeHigh
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(onPicked: onPicked, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
      UINavigationControllerDelegate
    {
      private let onPicked: (URL) -> Void
      private let dismiss: () -> Void

      init(onPicked: @escaping (URL) -> Void, dismiss: @escaping () -> Void) {
        self.onPicked = onPicked
        self.dismiss = dismiss
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        if let url = info[.mediaURL] as? URL {
          onPicked(url)
        }
        dismiss()
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss()
      }
    }
  }
#endif
