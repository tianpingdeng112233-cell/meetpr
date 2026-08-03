#if os(iOS)
  import AVFoundation
  import SwiftUI
  import UIKit

  struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewSurface {
      let view = PreviewSurface()
      view.previewLayer.session = session
      view.previewLayer.videoGravity = .resizeAspectFill
      return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {
      uiView.previewLayer.session = session
    }
  }

  final class PreviewSurface: UIView {
    // UIKit's layer-backed view contract requires a class override; `static`
    // cannot override `UIView.layerClass` even though this subclass is final.
    // swiftlint:disable:next static_over_final_class
    override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
      guard let layer = layer as? AVCaptureVideoPreviewLayer else {
        preconditionFailure("PreviewSurface must use AVCaptureVideoPreviewLayer")
      }
      return layer
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard previewLayer.connection?.isVideoRotationAngleSupported(90) == true else { return }
      previewLayer.connection?.videoRotationAngle = 90
    }
  }
#endif
