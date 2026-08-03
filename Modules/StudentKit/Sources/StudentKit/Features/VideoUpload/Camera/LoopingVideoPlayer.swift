#if os(iOS)
  import AVKit
  import SwiftUI
  import UIKit

  struct LoopingVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
      Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
      let controller = AVPlayerViewController()
      controller.player = context.coordinator.player
      controller.showsPlaybackControls = true
      controller.videoGravity = .resizeAspect
      context.coordinator.player.play()
      return controller
    }

    func updateUIViewController(
      _ uiViewController: AVPlayerViewController,
      context: Context
    ) {}

    static func dismantleUIViewController(
      _ uiViewController: AVPlayerViewController,
      coordinator: Coordinator
    ) {
      coordinator.player.pause()
      uiViewController.player = nil
    }

    final class Coordinator {
      let player: AVQueuePlayer
      private let looper: AVPlayerLooper

      init(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: item)
      }
    }
  }
#endif
