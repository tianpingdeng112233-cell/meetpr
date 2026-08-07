import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// Renders throwaway source movies for the exporter tests: configurable
/// resolution, frame rate, transform, entropy, and an optional audio track.
struct VideoExportFixture: Sendable {
  let directory: URL
  let sourceURL: URL
  let outputURL: URL

  static func make(_ configuration: VideoFixtureConfiguration) async throws -> VideoExportFixture {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fixture = VideoExportFixture(
      directory: directory,
      sourceURL: directory.appending(path: "source.mov"),
      outputURL: directory.appending(path: "output.mp4")
    )

    do {
      try await fixture.writeSourceVideo(configuration: configuration)
      return fixture
    } catch {
      fixture.remove()
      throw error
    }
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }

  private func writeSourceVideo(configuration: VideoFixtureConfiguration) async throws {
    let writer = try AVAssetWriter(outputURL: sourceURL, fileType: .mov)
    let (input, adaptor) = try Self.addVideoInput(to: writer, configuration: configuration)
    let audioInput = try Self.addAudioInput(to: writer, configuration: configuration)

    guard writer.startWriting() else {
      throw FixtureError.unavailable(writer.error?.localizedDescription ?? "Writer failed to start")
    }
    writer.startSession(atSourceTime: .zero)

    try await appendFrames(
      to: input,
      with: adaptor,
      writer: writer,
      configuration: configuration
    )
    input.markAsFinished()

    if let audioInput, let channelCount = configuration.audioChannelCount {
      try await FixtureAudio.append(
        to: audioInput,
        writer: writer,
        channelCount: channelCount,
        seconds: Double(configuration.frameCount) / Double(configuration.frameRate)
      )
      audioInput.markAsFinished()
    }

    await writer.finishWriting()
    guard writer.status == .completed else {
      throw FixtureError.unavailable(
        writer.error?.localizedDescription ?? "Fixture writer did not complete"
      )
    }
  }

  private static func addVideoInput(
    to writer: AVAssetWriter,
    configuration: VideoFixtureConfiguration
  ) throws -> (AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor) {
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: configuration.width,
        AVVideoHeightKey: configuration.height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: configuration.sourceBitRate
        ],
      ]
    )
    input.transform = configuration.preferredTransform
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: configuration.width,
        kCVPixelBufferHeightKey as String: configuration.height,
      ]
    )
    guard writer.canAdd(input) else {
      throw FixtureError.unavailable("Unable to add fixture video input")
    }
    writer.add(input)
    return (input, adaptor)
  }

  private static func addAudioInput(
    to writer: AVAssetWriter,
    configuration: VideoFixtureConfiguration
  ) throws -> AVAssetWriterInput? {
    guard let channelCount = configuration.audioChannelCount else { return nil }
    let input = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: configuration.audioEncoding.outputSettings(channelCount: channelCount)
    )
    guard writer.canAdd(input) else {
      throw FixtureError.unavailable("Unable to add fixture audio input")
    }
    writer.add(input)
    return input
  }

  private func appendFrames(
    to input: AVAssetWriterInput,
    with adaptor: AVAssetWriterInputPixelBufferAdaptor,
    writer: AVAssetWriter,
    configuration: VideoFixtureConfiguration
  ) async throws {
    for frameIndex in 0..<configuration.frameCount {
      while !input.isReadyForMoreMediaData {
        try await Task.sleep(for: .milliseconds(1))
      }
      let pixelBuffer = try makePixelBuffer(
        adaptor: adaptor,
        frameIndex: frameIndex,
        highEntropy: configuration.highEntropy
      )
      let presentationTime = CMTime(
        value: CMTimeValue(frameIndex),
        timescale: configuration.frameRate
      )
      guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
        throw FixtureError.unavailable(
          writer.error?.localizedDescription ?? "Unable to append fixture frame"
        )
      }
    }
  }

  private func makePixelBuffer(
    adaptor: AVAssetWriterInputPixelBufferAdaptor,
    frameIndex: Int,
    highEntropy: Bool
  ) throws -> CVPixelBuffer {
    // The host's pixel-buffer pool intermittently fails under parallel test
    // load; a short bounded retry keeps that infrastructure noise out of CI.
    var pixelBuffer: CVPixelBuffer?
    for attempt in 0..<3 {
      if let pool = adaptor.pixelBufferPool,
        case kCVReturnSuccess = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer),
        pixelBuffer != nil
      {
        break
      }
      if attempt < 2 { usleep(50_000) }
    }
    guard let pixelBuffer else {
      throw FixtureError.unavailable("Unable to allocate a fixture pixel buffer")
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw FixtureError.unavailable("Fixture pixel buffer has no base address")
    }
    let byteCount = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
    memset(baseAddress, Int32(frameIndex % 255), byteCount)
    if highEntropy {
      // Fresh per-frame noise in the top quarter defeats intra- and
      // inter-frame prediction there, forcing the encoder to spend real bits
      // (a flat fill compresses to almost nothing regardless of settings).
      // Full-frame noise would be pathological: even at its quantization
      // ceiling the encoder cannot reach the target, so the cap would be
      // untestable against it.
      arc4random_buf(baseAddress, byteCount / 4)
    }
    return pixelBuffer
  }
}

enum FixtureAudio {
  static let sampleRate = 44_100.0

  static func append(
    to input: AVAssetWriterInput,
    writer: AVAssetWriter,
    channelCount: Int,
    seconds: Double
  ) async throws {
    let formatDescription = try makeFormatDescription(channelCount: channelCount)
    let chunkFrames = 4_410
    let totalFrames = Int(seconds * sampleRate)
    var startFrame = 0
    while startFrame < totalFrames {
      while !input.isReadyForMoreMediaData {
        try await Task.sleep(for: .milliseconds(1))
      }
      let frameCount = min(chunkFrames, totalFrames - startFrame)
      let sampleBuffer = try makeSampleBuffer(
        formatDescription: formatDescription,
        frameCount: frameCount,
        channelCount: channelCount,
        startFrame: startFrame
      )
      guard input.append(sampleBuffer) else {
        throw FixtureError.unavailable(
          writer.error?.localizedDescription ?? "Unable to append fixture audio"
        )
      }
      startFrame += frameCount
    }
  }

  private static func makeFormatDescription(
    channelCount: Int
  ) throws -> CMAudioFormatDescription {
    var basicDescription = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
      mBytesPerPacket: UInt32(2 * channelCount),
      mFramesPerPacket: 1,
      mBytesPerFrame: UInt32(2 * channelCount),
      mChannelsPerFrame: UInt32(channelCount),
      mBitsPerChannel: 16,
      mReserved: 0
    )
    var formatDescription: CMAudioFormatDescription?
    let status = CMAudioFormatDescriptionCreate(
      allocator: kCFAllocatorDefault,
      asbd: &basicDescription,
      layoutSize: 0,
      layout: nil,
      magicCookieSize: 0,
      magicCookie: nil,
      extensions: nil,
      formatDescriptionOut: &formatDescription
    )
    guard status == noErr, let formatDescription else {
      throw FixtureError.unavailable("Unable to create the fixture audio format")
    }
    return formatDescription
  }

  private static func makeSampleBuffer(
    formatDescription: CMAudioFormatDescription,
    frameCount: Int,
    channelCount: Int,
    startFrame: Int
  ) throws -> CMSampleBuffer {
    let blockBuffer = try makeToneBlockBuffer(
      frameCount: frameCount,
      channelCount: channelCount,
      startFrame: startFrame
    )
    var sampleBuffer: CMSampleBuffer?
    let status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
      allocator: kCFAllocatorDefault,
      dataBuffer: blockBuffer,
      formatDescription: formatDescription,
      sampleCount: frameCount,
      presentationTimeStamp: CMTime(
        value: CMTimeValue(startFrame),
        timescale: CMTimeScale(sampleRate)
      ),
      packetDescriptions: nil,
      sampleBufferOut: &sampleBuffer
    )
    guard status == noErr, let sampleBuffer else {
      throw FixtureError.unavailable("Unable to create a fixture audio sample")
    }
    return sampleBuffer
  }

  private static func makeToneBlockBuffer(
    frameCount: Int,
    channelCount: Int,
    startFrame: Int
  ) throws -> CMBlockBuffer {
    let byteCount = frameCount * channelCount * 2
    var blockBuffer: CMBlockBuffer?
    let blockStatus = CMBlockBufferCreateWithMemoryBlock(
      allocator: kCFAllocatorDefault,
      memoryBlock: nil,
      blockLength: byteCount,
      blockAllocator: nil,
      customBlockSource: nil,
      offsetToData: 0,
      dataLength: byteCount,
      flags: 0,
      blockBufferOut: &blockBuffer
    )
    guard blockStatus == kCMBlockBufferNoErr, let blockBuffer else {
      throw FixtureError.unavailable("Unable to allocate a fixture audio buffer")
    }

    var samples = [Int16](repeating: 0, count: frameCount * channelCount)
    for frame in 0..<frameCount {
      let phase = 2 * Double.pi * 440 * Double(startFrame + frame) / sampleRate
      let value = Int16(8_000 * sin(phase))
      for channel in 0..<channelCount {
        samples[frame * channelCount + channel] = value
      }
    }
    try samples.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else {
        throw FixtureError.unavailable("Fixture audio samples have no base address")
      }
      let fillStatus = CMBlockBufferReplaceDataBytes(
        with: base,
        blockBuffer: blockBuffer,
        offsetIntoDestination: 0,
        dataLength: byteCount
      )
      guard fillStatus == kCMBlockBufferNoErr else {
        throw FixtureError.unavailable("Unable to fill the fixture audio buffer")
      }
    }
    return blockBuffer
  }
}

struct VideoFixtureConfiguration: Sendable {
  let frameCount: Int
  var preferredTransform: CGAffineTransform = .identity
  var width = 320
  var height = 180
  var frameRate: Int32 = 30
  var sourceBitRate = 400_000
  var highEntropy = false
  var audioChannelCount: Int?
  var audioEncoding: FixtureAudioEncoding = .pcm
}

enum FixtureAudioEncoding: Sendable {
  case pcm
  case aac

  func outputSettings(channelCount: Int) -> [String: Any] {
    switch self {
    case .pcm:
      [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: FixtureAudio.sampleRate,
        AVNumberOfChannelsKey: channelCount,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    case .aac:
      [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVEncoderBitRateKey: 96_000,
        AVSampleRateKey: FixtureAudio.sampleRate,
        AVNumberOfChannelsKey: channelCount,
      ]
    }
  }
}

enum FixtureError: Error {
  case unavailable(String)
}
