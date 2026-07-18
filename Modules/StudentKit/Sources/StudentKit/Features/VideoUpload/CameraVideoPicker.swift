import Foundation

enum CameraVideoFileCopy {
  static func copyToTemporaryDirectory(
    sourceURL: URL,
    temporaryDirectory: URL = FileManager.default.temporaryDirectory,
    fileManager: FileManager = .default
  ) throws -> URL {
    let destination =
      temporaryDirectory
      .appending(path: "\(UUID().uuidString).\(sourceURL.pathExtension)")
    try fileManager.copyItem(at: sourceURL, to: destination)
    return destination
  }
}

/// Platform-neutral capture handoff decision so the host test suite can lock
/// the picker's semantics (the UIKit Coordinator is `#if os(iOS)`-only and its
/// tests would silently not run on the macOS host).
enum CameraCaptureHandoff: Equatable {
  case picked(URL)
  case failed

  /// The captured tmp file must be secured (copied) BEFORE the picker is
  /// dismissed — the system may reclaim `mediaURL` on dismissal. Callers run
  /// this first and dismiss only after acting on the outcome.
  static func process(mediaURL: URL?, copy: (URL) throws -> URL) -> CameraCaptureHandoff {
    guard let mediaURL else { return .failed }
    do {
      return .picked(try copy(mediaURL))
    } catch {
      return .failed
    }
  }
}

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
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = [UTType.movie.identifier]
      picker.cameraCaptureMode = .video
      picker.cameraFlashMode = .off
      picker.videoMaximumDuration = maxDurationSeconds
      picker.videoQuality = .typeHigh
      picker.allowsEditing = true
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(onPicked: onPicked, onFailure: onFailure, close: { isPresented = false })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
      UINavigationControllerDelegate
    {
      private let onPicked: (URL) -> Void
      private let onFailure: () -> Void
      private let close: () -> Void
      private let singleShot = SingleShot()

      init(
        onPicked: @escaping (URL) -> Void,
        onFailure: @escaping () -> Void,
        close: @escaping () -> Void
      ) {
        self.onPicked = onPicked
        self.onFailure = onFailure
        self.close = close
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        singleShot.run {
          // With `allowsEditing`, `.mediaURL` is the trimmed movie.
          let outcome = CameraCaptureHandoff.process(
            mediaURL: info[.mediaURL] as? URL,
            copy: { try CameraVideoFileCopy.copyToTemporaryDirectory(sourceURL: $0) }
          )
          switch outcome {
          case .picked(let copiedURL): onPicked(copiedURL)
          case .failed: onFailure()
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
