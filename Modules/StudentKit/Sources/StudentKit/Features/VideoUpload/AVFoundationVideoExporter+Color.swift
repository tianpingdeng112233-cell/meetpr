import AVFoundation
import CoreMedia
import CoreVideo

extension AVFoundationVideoExporter {
  static let sdrColorProperties: [String: String] = [
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
  ]

  static func requiresSDRConversion(_ track: AVAssetTrack) async throws -> Bool {
    let descriptions = try await track.load(.formatDescriptions)
    return descriptions.contains { description in
      let primaries =
        CMFormatDescriptionGetExtension(
          description, extensionKey: kCMFormatDescriptionExtension_ColorPrimaries) as? String
      let transfer =
        CMFormatDescriptionGetExtension(
          description, extensionKey: kCMFormatDescriptionExtension_TransferFunction) as? String
      return primaries == AVVideoColorPrimaries_ITU_R_2020
        || primaries == AVVideoColorPrimaries_P3_D65
        || primaries == kCVImageBufferColorPrimaries_DCI_P3 as String
        || transfer == AVVideoTransferFunction_ITU_R_2100_HLG
        || transfer == AVVideoTransferFunction_SMPTE_ST_2084_PQ
    }
  }
}
