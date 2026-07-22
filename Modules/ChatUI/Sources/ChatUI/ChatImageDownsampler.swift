import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ChatImageDownsamplingError: Error, Equatable, Sendable {
  case invalidImage
  case encodingFailed
}

public struct ChatImageDownsampler: Sendable {
  public static let maximumPixelDimension = 1_600
  public static let compressionQuality = 0.7

  public init() {}

  public func downsampleJPEG(_ imageData: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
      throw ChatImageDownsamplingError.invalidImage
    }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: Self.maximumPixelDimension,
    ]
    guard
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        thumbnailOptions as CFDictionary
      )
    else {
      throw ChatImageDownsamplingError.invalidImage
    }

    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      throw ChatImageDownsamplingError.encodingFailed
    }

    let destinationOptions: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: Self.compressionQuality
    ]
    CGImageDestinationAddImage(destination, thumbnail, destinationOptions as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw ChatImageDownsamplingError.encodingFailed
    }
    return output as Data
  }
}
