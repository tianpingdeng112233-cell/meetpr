import AVFoundation
import Testing

@testable import StudentKit

@MainActor
struct UploadAudioSessionTests {
  @Test func uploadRecorderAllowsExternalMusicBeforeStartingCapture() {
    let controller = RecorderSessionController(maximumDuration: 10)
    #expect(!controller.captureSession.automaticallyConfiguresApplicationAudioSession)
  }

  @Test func captureAndNestedUploadPreviewsKeepMixingUntilTheLastPlayerLeaves() throws {
    let session = AVAudioSession.sharedInstance()
    let original = session.category
    let options = session.categoryOptions
    do {
      let review = try UploadVideoAudio(.preview)
      #expect(session.category == .ambient)
      do {
        let camera = try UploadVideoAudio(.capture)
        #expect(session.category == .playAndRecord)
        #expect(session.categoryOptions.contains(.mixWithOthers))
        let trim = try UploadVideoAudio(.preview)
        #expect(session.category == .playAndRecord)
        withExtendedLifetime((camera, trim)) {}
      }
      #expect(session.category == .ambient)
      withExtendedLifetime(review) {}
    }
    #expect(session.category == original)
    #expect(session.categoryOptions == options)
  }
}
