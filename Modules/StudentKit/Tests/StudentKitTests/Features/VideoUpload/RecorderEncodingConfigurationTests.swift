import AVFoundation
import Testing
import VideoToolbox

@testable import StudentKit

@Test("Recorder video writer settings enforce the upload-ready H.264 budget")
func recorderVideoWriterSettingsMatchUploadBudget() throws {
  let settings = RecorderWriterSettings.video()
  let compression = try #require(
    settings[AVVideoCompressionPropertiesKey] as? [String: Any]
  )
  let dataRateLimits = try #require(
    compression[kVTCompressionPropertyKey_DataRateLimits as String] as? [Int]
  )

  #expect(settings[AVVideoCodecKey] as? AVVideoCodecType == .h264)
  #expect(settings[AVVideoWidthKey] as? Int == 720)
  #expect(settings[AVVideoHeightKey] as? Int == 1_280)
  #expect(compression[AVVideoAverageBitRateKey] as? Int == 2_750_000)
  #expect(compression[AVVideoProfileLevelKey] as? String == AVVideoProfileLevelH264HighAutoLevel)
  #expect(dataRateLimits == [437_500, 1])
  #expect(RecorderWriterSettings.videoTransform == .identity)
}

@Test("Recorder audio writer settings encode mono AAC at 96 kbps")
func recorderAudioWriterSettingsMatchUploadBudget() throws {
  let settings = RecorderWriterSettings.audio()
  let formatID = try #require(settings[AVFormatIDKey] as? UInt32)

  #expect(formatID == kAudioFormatMPEG4AAC)
  #expect(settings[AVEncoderBitRateKey] as? Int == 96_000)
  #expect(settings[AVSampleRateKey] as? Int == 44_100)
  #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
}
