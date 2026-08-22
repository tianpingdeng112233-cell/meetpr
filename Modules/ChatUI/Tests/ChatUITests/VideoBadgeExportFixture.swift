import AVFoundation
import CoreVideo
import Foundation

struct VideoBadgeExportFixture: Sendable {
  let directory: URL
  let sourceURL: URL

  static func makePortrait() async throws -> VideoBadgeExportFixture {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: UUID().uuidString,
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fixture = VideoBadgeExportFixture(
      directory: directory,
      sourceURL: directory.appending(path: "portrait-source.mov")
    )
    do {
      try await fixture.writeSource()
      return fixture
    } catch {
      fixture.remove()
      throw error
    }
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }

  private func writeSource() async throws {
    let frameRate: CMTimeScale = 24
    let frameCount = 12
    let pipeline = try makeWriterPipeline()
    guard pipeline.writer.startWriting() else {
      throw pipeline.writer.error ?? VideoBadgeFixtureError.writerUnavailable
    }
    pipeline.writer.startSession(atSourceTime: .zero)
    try await writeVideoFrames(
      writer: pipeline.writer,
      input: pipeline.videoInput,
      adaptor: pipeline.adaptor,
      frameCount: frameCount,
      frameRate: frameRate
    )
    for audioInput in pipeline.audioInputs {
      try await writeSilentAudio(
        writer: pipeline.writer,
        audioInput: audioInput,
        seconds: Double(frameCount) / Double(frameRate)
      )
    }
    await pipeline.writer.finishWriting()
    guard pipeline.writer.status == .completed else {
      throw pipeline.writer.error ?? VideoBadgeFixtureError.writerUnavailable
    }
  }

  private struct WriterPipeline {
    let writer: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let audioInputs: [AVAssetWriterInput]
  }

  private func makeWriterPipeline() throws -> WriterPipeline {
    let width = 320
    let height = 180
    let writer = try AVAssetWriter(outputURL: sourceURL, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
    )
    input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )
    // Two audio tracks so the exporter's copy-all-audio behavior has a real
    // regression check — a first-track-only implementation drops one.
    let audioInputs = (0..<2).map { _ in
      AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44_100,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 64_000,
        ]
      )
    }
    guard writer.canAdd(input), audioInputs.allSatisfy(writer.canAdd) else {
      throw VideoBadgeFixtureError.writerUnavailable
    }
    writer.add(input)
    audioInputs.forEach(writer.add)
    return WriterPipeline(
      writer: writer,
      videoInput: input,
      adaptor: adaptor,
      audioInputs: audioInputs
    )
  }

  private func writeVideoFrames(
    writer: AVAssetWriter,
    input: AVAssetWriterInput,
    adaptor: AVAssetWriterInputPixelBufferAdaptor,
    frameCount: Int,
    frameRate: CMTimeScale
  ) async throws {
    for frameIndex in 0..<frameCount {
      while !input.isReadyForMoreMediaData {
        try await Task.sleep(for: .milliseconds(1))
      }
      let pixelBuffer = try makePixelBuffer(adaptor: adaptor, frameIndex: frameIndex)
      guard
        adaptor.append(
          pixelBuffer,
          withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: frameRate)
        )
      else {
        throw writer.error ?? VideoBadgeFixtureError.writerUnavailable
      }
    }
    input.markAsFinished()
  }

  private func writeSilentAudio(
    writer: AVAssetWriter,
    audioInput: AVAssetWriterInput,
    seconds: Double
  ) async throws {
    let silence = try Self.makeSilenceBuffer(seconds: seconds, sampleRate: 44_100)
    while !audioInput.isReadyForMoreMediaData {
      try await Task.sleep(for: .milliseconds(1))
    }
    guard audioInput.append(silence) else {
      throw writer.error ?? VideoBadgeFixtureError.writerUnavailable
    }
    audioInput.markAsFinished()
  }

  /// Flat gray frame with a red marker in the natural-coordinates region that
  /// the 90° preferredTransform maps to the displayed top-left corner. Any
  /// orientation mistake in the exporter moves the marker after transform.
  private func makePixelBuffer(
    adaptor: AVAssetWriterInputPixelBufferAdaptor,
    frameIndex: Int
  ) throws -> CVPixelBuffer {
    guard let pool = adaptor.pixelBufferPool else {
      throw VideoBadgeFixtureError.pixelBufferUnavailable
    }
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
      let pixelBuffer
    else {
      throw VideoBadgeFixtureError.pixelBufferUnavailable
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw VideoBadgeFixtureError.pixelBufferUnavailable
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    memset(baseAddress, 190, bytesPerRow * height)

    // Display (x', y') = (180 - y, x): displayed top-left 60×60 comes from
    // natural x ∈ [0, 60), y ∈ [120, 180). BGRA byte order.
    let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
    for y in 120..<min(180, height) {
      for x in 0..<min(60, width) {
        let offset = y * bytesPerRow + x * 4
        buffer[offset] = 30
        buffer[offset + 1] = 30
        buffer[offset + 2] = 230
        buffer[offset + 3] = 255
      }
    }
    return pixelBuffer
  }

  private static func makeSilenceBuffer(
    seconds: Double,
    sampleRate: Double
  ) throws -> CMSampleBuffer {
    let formatDescription = try makeMonoPCMFormat(sampleRate: sampleRate)
    let frameCount = Int(seconds * sampleRate)
    let blockBuffer = try makeZeroedBlockBuffer(dataLength: frameCount * 2)
    var sampleBuffer: CMSampleBuffer?
    guard
      CMAudioSampleBufferCreateReadyWithPacketDescriptions(
        allocator: kCFAllocatorDefault,
        dataBuffer: blockBuffer,
        formatDescription: formatDescription,
        sampleCount: frameCount,
        presentationTimeStamp: .zero,
        packetDescriptions: nil,
        sampleBufferOut: &sampleBuffer
      ) == noErr, let sampleBuffer
    else {
      throw VideoBadgeFixtureError.writerUnavailable
    }
    return sampleBuffer
  }

  private static func makeMonoPCMFormat(sampleRate: Double) throws -> CMAudioFormatDescription {
    var streamDescription = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
      mBytesPerPacket: 2,
      mFramesPerPacket: 1,
      mBytesPerFrame: 2,
      mChannelsPerFrame: 1,
      mBitsPerChannel: 16,
      mReserved: 0
    )
    var formatDescription: CMAudioFormatDescription?
    guard
      CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &streamDescription,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDescription
      ) == noErr, let formatDescription
    else {
      throw VideoBadgeFixtureError.writerUnavailable
    }
    return formatDescription
  }

  private static func makeZeroedBlockBuffer(dataLength: Int) throws -> CMBlockBuffer {
    var blockBuffer: CMBlockBuffer?
    guard
      CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: dataLength,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: dataLength,
        flags: 0,
        blockBufferOut: &blockBuffer
      ) == noErr, let blockBuffer,
      CMBlockBufferFillDataBytes(
        with: 0,
        blockBuffer: blockBuffer,
        offsetIntoDestination: 0,
        dataLength: dataLength
      ) == noErr
    else {
      throw VideoBadgeFixtureError.writerUnavailable
    }
    return blockBuffer
  }
}

enum VideoBadgeFixtureError: Error {
  case pixelBufferUnavailable
  case writerUnavailable
}
