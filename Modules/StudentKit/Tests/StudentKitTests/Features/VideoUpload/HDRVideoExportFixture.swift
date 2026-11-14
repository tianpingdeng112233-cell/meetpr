import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

struct HDRVideoExportFixture {
  static func make() async throws -> VideoExportFixture {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fixture = VideoExportFixture(
      directory: directory, sourceURL: directory.appending(path: "hlg.mov"),
      outputURL: directory.appending(path: "sdr.mp4"))
    do {
      try await write(to: fixture.sourceURL)
      return fixture
    } catch {
      fixture.remove()
      throw error
    }
  }

  private static func write(to url: URL) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: 320,
        AVVideoHeightKey: 180,
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
        ],
        AVVideoCompressionPropertiesKey: [
          AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel
        ],
      ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        kCVPixelBufferWidthKey as String: 320,
        kCVPixelBufferHeightKey as String: 180,
      ])
    writer.add(input)
    guard writer.startWriting() else { throw FixtureError.unavailable("HEVC writer start failed") }
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<10 {
      while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else {
          throw FixtureError.unavailable("HEVC writer failed")
        }
        try await Task.sleep(for: .milliseconds(1))
      }
      let buffer = try makeBuffer(pool: adaptor.pixelBufferPool)
      guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30))
      else { throw FixtureError.unavailable("HEVC frame failed") }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw FixtureError.unavailable("HEVC fixture did not complete")
    }
  }

  private static func makeBuffer(pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    guard let pool,
      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
      let buffer
    else { throw FixtureError.unavailable("No 10-bit pixel buffer") }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    for plane in 0..<CVPixelBufferGetPlaneCount(buffer) {
      guard let address = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) else {
        throw FixtureError.unavailable("Missing pixel plane")
      }
      let count =
        CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
        * CVPixelBufferGetHeightOfPlane(buffer, plane) / 2
      let pixels = address.assumingMemoryBound(to: UInt16.self)
      for index in 0..<count { pixels[index] = UInt16(plane == 0 ? 600 : 512) << 6 }
    }
    CVBufferSetAttachment(
      buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020,
      .shouldPropagate)
    CVBufferSetAttachment(
      buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG,
      .shouldPropagate)
    CVBufferSetAttachment(
      buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020,
      .shouldPropagate)
    return buffer
  }
}
