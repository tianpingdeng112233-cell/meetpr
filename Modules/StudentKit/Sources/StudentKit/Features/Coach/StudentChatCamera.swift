import ChatUI
import DesignSystem
import SwiftUI

#if os(iOS)
  import AVFoundation
  import UIKit
  import UniformTypeIdentifiers

  struct StudentChatCamera: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = [UTType.image.identifier]
      picker.cameraCaptureMode = .photo
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
      UINavigationControllerDelegate
    {
      let parent: StudentChatCamera
      init(parent: StudentChatCamera) { self.parent = parent }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        guard let image = info[.originalImage] as? UIImage,
          let data = image.jpegData(compressionQuality: 1)
        else {
          parent.onCancel()
          return
        }
        parent.onPhoto(data)
      }
    }
  }
#endif

struct StudentChatPhotoPreview: View {
  let data: Data
  let onRetake: () -> Void
  let onSend: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.space4) {
      StudentChatLocalImage(data: data)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      HStack {
        Button(StudentStrings.localized(.weightDismiss), action: onCancel)
        Spacer()
        Button(StudentStrings.localized(.coachPhotoRetake), action: onRetake)
        Button(StudentStrings.localized(.allDaySend), action: onSend)
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.goldCTA)
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.bgBase)
  }
}

struct StudentChatLocalImage: View {
  let data: Data

  var body: some View {
    #if os(iOS)
      if let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFit()
      }
    #else
      if let image = NSImage(data: data) {
        Image(nsImage: image).resizable().scaledToFit()
      }
    #endif
  }
}
