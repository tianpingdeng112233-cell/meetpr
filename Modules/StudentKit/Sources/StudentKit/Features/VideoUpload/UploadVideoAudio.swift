#if os(iOS)
  import AVFAudio
  import Foundation

  /// Capture runs on its session queue while SwiftUI can present overlapping review and trim
  /// players. Keep the shared audio session mixable until the last of those consumers closes.
  final class UploadVideoAudio: Sendable {
    enum Use: Sendable { case capture, preview }

    private static let state = State()
    private let use: Use

    init(_ use: Use) throws {
      try Self.state.acquire(use)
      self.use = use
    }

    deinit { Self.state.release(use) }

    private struct Configuration {
      let category: AVAudioSession.Category
      let mode: AVAudioSession.Mode
      let options: AVAudioSession.CategoryOptions
    }

    private final class State: @unchecked Sendable {
      private let lock = NSLock()
      private let session = AVAudioSession.sharedInstance()
      private var captures = 0
      private var previews = 0
      private var original: Configuration?

      func acquire(_ use: Use) throws {
        lock.lock()
        defer { lock.unlock() }
        let first = captures == 0 && previews == 0
        if first && original == nil {
          original = Configuration(
            category: session.category, mode: session.mode, options: session.categoryOptions)
        }
        do {
          if use == .capture {
            try session.setCategory(
              .playAndRecord, mode: .videoRecording,
              options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
          } else if first {
            try session.setCategory(.ambient, mode: .default)
          }
        } catch {
          if first {
            restore()
          } else if captures == 0 {
            try? session.setCategory(.ambient, mode: .default)
          }
          throw error
        }
        if use == .capture { captures += 1 } else { previews += 1 }
      }

      func release(_ use: Use) {
        lock.lock()
        defer { lock.unlock() }
        if use == .capture { captures -= 1 } else { previews -= 1 }
        guard captures == 0 else { return }
        if previews == 0 {
          restore()
        } else if use == .capture {
          try? session.setCategory(.ambient, mode: .default)
        }
      }

      private func restore() {
        guard let original else { return }
        do {
          try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
          // On iOS 17–25, isBusy signals that deactivation stopped a running I/O.
          // Other errors do not confirm deactivation. The next close retries restoration.
          guard error.domain == NSOSStatusErrorDomain,
            error.code == AVAudioSession.ErrorCode.isBusy.rawValue
          else { return }
        }
        do {
          try session.setCategory(original.category, mode: original.mode, options: original.options)
          self.original = nil
        } catch {
          // Preserve the pre-upload settings for the next close.
        }
      }
    }
  }
#endif
