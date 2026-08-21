import AVFoundation
import CoreVideo
import Foundation
import Testing

@testable import ChatUI

@Suite("Video badge exporter")
struct VideoBadgeExporterTests {
  @Test("export preserves orientation, audio, duration, and burns the badge into every segment")
  @MainActor
  func exportPreservesVideoContract() async throws {
    let fixture = try await VideoBadgeExportFixture.makePortrait()
    defer { fixture.remove() }

    let source = AVURLAsset(url: fixture.sourceURL)
    let sourceDuration = try await source.load(.duration)
    let outputURL = try await VideoBadgeExporter().export(
      sourceURL: fixture.sourceURL,
      badge: VideoBadgeInfo(
        exerciseName: "传统硬拉",
        weightKg: 180,
        reps: 4,
        rpe: 8.5,
        setOrdinal: 3,
        coachName: "陈教练"
      )
    )
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let output = AVURLAsset(url: outputURL)
    let outputDuration = try await output.load(.duration)
    let videoTracks = try await output.loadTracks(withMediaType: .video)
    let audioTracks = try await output.loadTracks(withMediaType: .audio)
    let track = try #require(videoTracks.first)
    let naturalSize = try await track.load(.naturalSize)
    let preferredTransform = try await track.load(.preferredTransform)
    let displayedBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
    let nominalFrameRate = try await track.load(.nominalFrameRate)

    #expect(abs(outputDuration.seconds - sourceDuration.seconds) < 0.05)
    #expect(videoTracks.count == 1)
    let sourceAudioTracks = try await source.loadTracks(withMediaType: .audio)
    #expect(sourceAudioTracks.count == 2)
    #expect(audioTracks.count == sourceAudioTracks.count)
    #expect(abs(displayedBounds.width) < abs(displayedBounds.height))
    #expect(abs(Double(nominalFrameRate) - 24.0) < 1.5)

    // Orientation ground truth: the source frame carries an asymmetric red
    // marker. Running source and export through the same display-transformed
    // frame pipeline must keep the marker centroid in place — a dropped or
    // doubled preferredTransform moves it (or changes the displayed size).
    let sourceFrame = try Self.displayedFrame(of: source, atSeconds: 0.1)
    let sourceStats = Self.pixelStats(in: sourceFrame)
    let sourceCentroid = try #require(sourceStats.redCentroid)
    #expect(sourceStats.goldCount < 5)

    for sampleSeconds in [0.05, 0.25, 0.45] {
      let frame = try Self.displayedFrame(of: output, atSeconds: sampleSeconds)
      #expect(frame.width == sourceFrame.width)
      #expect(frame.height == sourceFrame.height)
      let stats = Self.pixelStats(in: frame)
      let centroid = try #require(stats.redCentroid)
      #expect(abs(centroid.x - sourceCentroid.x) < 15)
      #expect(abs(centroid.y - sourceCentroid.y) < 15)
      // Badge presence on every sampled segment: gold (logo/RPE capsule) and
      // bright text pixels that the flat gray-plus-red source cannot produce.
      #expect(stats.goldCount > 30)
      #expect(stats.brightCount > 100)
      // The badge hugs the bottom edge, the red marker the top corner — their
      // vertical separation proves the card really sits in the bottom band.
      if let goldCentroid = stats.goldCentroid {
        #expect(abs(goldCentroid.y - centroid.y) > Double(frame.height) * 0.4)
      }
      Self.expectScrimDarkensBottomBand(of: frame)
    }
  }

  /// Scrim: the flat-gray source must be darkened in the bottom band only.
  /// Samples a column outside the card (right edge) and the red marker.
  private static func expectScrimDarkensBottomBand(of frame: CGImage) {
    let column = frame.width - 4
    let top = luminance(in: frame, x: column, y: 8)
    let middle = luminance(in: frame, x: column, y: frame.height / 2)
    let bottom = luminance(in: frame, x: column, y: frame.height - 6)
    #expect(abs(top - 190) < 12)
    #expect(abs(middle - 190) < 16)
    #expect(bottom < top * 0.6)
  }

  private static func luminance(in image: CGImage, x: Int, y: Int) -> Double {
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = CGContext(
      data: &pixel,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    let origin = CGPoint(x: -x, y: -(image.height - 1 - y))
    context?.draw(
      image,
      in: CGRect(origin: origin, size: CGSize(width: image.width, height: image.height))
    )
    return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / 3
  }

  private static func displayedFrame(
    of asset: AVAsset,
    atSeconds seconds: Double
  ) throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try generator.copyCGImage(
      at: CMTime(seconds: seconds, preferredTimescale: 600),
      actualTime: nil
    )
  }

  private struct PixelStats {
    var redCentroid: (x: Double, y: Double)?
    var goldCentroid: (x: Double, y: Double)?
    var goldCount: Int
    var brightCount: Int
  }

  private static func pixelStats(in image: CGImage) -> PixelStats {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
      data: &pixels,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var redSumX = 0.0
    var redSumY = 0.0
    var redCount = 0
    var goldSumX = 0.0
    var goldSumY = 0.0
    var goldCount = 0
    var brightCount = 0
    for y in 0..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        if red > 170, green < 110, blue < 110 {
          redSumX += Double(x)
          redSumY += Double(y)
          redCount += 1
        } else if red > 140, green > 80, green < 210, blue < 110, red > blue + 60 {
          goldSumX += Double(x)
          goldSumY += Double(y)
          goldCount += 1
        } else if red > 200, green > 200, blue > 200 {
          brightCount += 1
        }
      }
    }
    return PixelStats(
      redCentroid: redCount > 0 ? (redSumX / Double(redCount), redSumY / Double(redCount)) : nil,
      goldCentroid: goldCount > 0
        ? (goldSumX / Double(goldCount), goldSumY / Double(goldCount)) : nil,
      goldCount: goldCount,
      brightCount: brightCount
    )
  }
}
