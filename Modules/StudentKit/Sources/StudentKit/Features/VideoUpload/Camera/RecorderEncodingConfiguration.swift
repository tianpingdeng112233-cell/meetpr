import AVFoundation
import VideoToolbox

struct RecorderEncodingConfiguration: Equatable, Sendable {
  let width: Int
  let height: Int
  let averageVideoBitRate: Int
  let peakVideoBitRate: Int
  let audioBitRate: Int
  let audioSampleRate: Int
  let audioChannelCount: Int

  static let uploadReady = RecorderEncodingConfiguration(
    width: 720,
    height: 1_280,
    averageVideoBitRate: 2_750_000,
    peakVideoBitRate: 3_500_000,
    audioBitRate: 96_000,
    audioSampleRate: 44_100,
    audioChannelCount: 1
  )
}

/// Actual AVAssetWriter settings shared by the iOS recorder and macOS host
/// tests, so delivery-budget changes cannot drift behind constant-only tests.
enum RecorderWriterSettings {
  static let videoTransform = CGAffineTransform.identity

  static func video(
    configuration: RecorderEncodingConfiguration = .uploadReady
  ) -> [String: Any] {
    [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: configuration.width,
      AVVideoHeightKey: configuration.height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: configuration.averageVideoBitRate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        kVTCompressionPropertyKey_DataRateLimits as String: [
          configuration.peakVideoBitRate / 8, 1,
        ],
      ],
    ]
  }

  static func audio(
    configuration: RecorderEncodingConfiguration = .uploadReady
  ) -> [String: Any] {
    [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVEncoderBitRateKey: configuration.audioBitRate,
      AVSampleRateKey: configuration.audioSampleRate,
      AVNumberOfChannelsKey: configuration.audioChannelCount,
    ]
  }
}
