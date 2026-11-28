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
        setOrdinal: 3
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
    #expect(try await source.loadTracks(withMediaType: .audio).count == 2)
    #expect(audioTracks.count == 2)
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
      #expect(stats.goldCount > 30)
      #expect(stats.brightCount > 100)
      Self.expectCardBounds(stats.cardBounds, in: frame)
      Self.expectOnlyCardDarkensFrame(frame)
    }
  }

  @Test(arguments: [CGSize(width: 1920, height: 1080), CGSize(width: 1080, height: 1440)])
  @MainActor
  func exportPlacesCardInFrame(_ size: CGSize) async throws {
    let fixture = try await VideoBadgeExportFixture.make(size: size)
    defer { fixture.remove() }
    let url = try await VideoBadgeExporter().export(
      sourceURL: fixture.sourceURL,
      badge: VideoBadgeInfo(exerciseName: "Squat", weightKg: 180, reps: 4, rpe: 8.5))
    defer { try? FileManager.default.removeItem(at: url) }
    let frame = try Self.displayedFrame(of: AVURLAsset(url: url), atSeconds: 0.25)
    #expect(frame.width == Int(size.width) && frame.height == Int(size.height))
    let stats = Self.pixelStats(in: frame)
    #expect(stats.goldCount > 30 && stats.brightCount > 100)
    Self.expectCardBounds(stats.cardBounds, in: frame)
  }

  private static func expectCardBounds(_ bounds: CGRect, in frame: CGImage) {
    let height = CGFloat(frame.height)
    let scale = min(CGFloat(frame.width), height * 9 / 16) / 540
    #expect(!bounds.isNull)
    #expect(abs(bounds.minX - 44 * scale) <= 2)
    #expect(abs(height - bounds.maxY - 214 * scale) <= 2)
    #expect(bounds.height >= 95 * scale && bounds.height <= height * 0.20)
  }

  private static func expectOnlyCardDarkensFrame(_ frame: CGImage) {
    // The 180×320 fixture scales the artboard by 1/3. The card starts at
    // x≈15 and ends at y≈249. Sample its bottom padding, away from glyphs.
    let clearColumn = frame.width - 4
    #expect(abs(luminance(in: frame, x: clearColumn, y: 8) - 190) < 12)
    #expect(abs(luminance(in: frame, x: clearColumn, y: frame.height / 2) - 190) < 16)
    let card = luminance(in: frame, x: 35, y: 246)
    let bottom = luminance(in: frame, x: 35, y: frame.height - 6)
    #expect(card < 140)
    #expect(abs(bottom - 190) < 12)
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
    var cardBounds: CGRect
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

    var cardBounds = CGRect.null
    var redSumX = 0.0
    var redSumY = 0.0
    var redCount = 0
    var goldCount = 0
    var brightCount = 0
    for y in 0..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        // Exclude the fixture's orientation fiducial and its codec halo.
        if x > 64 || y > 184, red < 145, green < 145, blue < 145 {
          cardBounds = cardBounds.union(CGRect(x: x, y: y, width: 1, height: 1))
        }
        if red > 170, green < 110, blue < 110 {
          redSumX += Double(x)
          redSumY += Double(y)
          redCount += 1
        } else if red > 140, green > 80, green < 210, blue < 110, red > blue + 60 {
          goldCount += 1
        } else if red > 200, green > 200, blue > 200 {
          brightCount += 1
        }
      }
    }
    return PixelStats(
      redCentroid: redCount > 0 ? (redSumX / Double(redCount), redSumY / Double(redCount)) : nil,
      cardBounds: cardBounds, goldCount: goldCount,
      brightCount: brightCount
    )
  }
}
