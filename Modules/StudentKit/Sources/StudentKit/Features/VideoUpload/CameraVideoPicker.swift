#if os(iOS)
  import SwiftUI
  import UIKit
  import UniformTypeIdentifiers

  /// UIImagePickerController wrapper for in-app video capture (spec 027).
  /// Caps recording at `maxDurationSeconds` — the picker stops automatically.
  ///
  /// Closes by flipping the presenting binding, NOT `@Environment(\.dismiss)`:
  /// this cover is hosted by the set-entry sheet, and an environment dismiss
  /// racing the picker's own teardown can pop the sheet itself — the sheet
  /// then re-presents with reset fields (beta 2026-07-11, 拍摄 path).
  struct CameraVideoPicker: UIViewControllerRepresentable {
    let maxDurationSeconds: TimeInterval
    @Binding var isPresented: Bool
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = [UTType.movie.identifier]
      picker.cameraCaptureMode = .video
      picker.videoMaximumDuration = maxDurationSeconds
      picker.videoQuality = .typeHigh
      picker.allowsEditing = true
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(onPicked: onPicked, close: { isPresented = false })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
      UINavigationControllerDelegate
    {
      private let onPicked: (URL) -> Void
      private let close: () -> Void
      private let singleShot = SingleShot()

      init(onPicked: @escaping (URL) -> Void, close: @escaping () -> Void) {
        self.onPicked = onPicked
        self.close = close
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        singleShot.run {
          // With `allowsEditing`, `.mediaURL` is the trimmed movie.
          if let url = info[.mediaURL] as? URL {
            onPicked(url)
          }
          close()
        }
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        singleShot.run { close() }
      }
    }
  }
#endif
