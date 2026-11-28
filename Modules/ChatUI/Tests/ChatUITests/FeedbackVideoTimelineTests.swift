import CoreModels
import Foundation
import SwiftUI
import Testing

@testable import ChatUI

@Suite @MainActor struct FeedbackVideoTimelineTests {
  @Test(arguments: ["cue", String(repeating: "长点评", count: 28)])
  func renderedCueClearsBadgeAndScrubber(note: String) throws {
    let size = CGSize(width: 390, height: 844)
    let scale = VideoBadgeLayout(size: size).scale
    let marker = VideoMarker(
      id: UUID(), videoID: UUID(), coachID: UUID(), timeMilliseconds: 1000, level: .info,
      note: note, createdAt: .now)
    func darkBands(seconds: Double, showsAnnotation: Bool = false) throws -> [Range<Int>] {
      let timeline = FeedbackVideoTimeline(
        badge: .init(exerciseName: "Squat", reps: 5), showsAnnotation: showsAnnotation,
        markers: [marker],
        markersFailed: false, seconds: seconds, duration: 8, select: { _ in }, update: { _ in },
        setScrubbing: { _ in }, refresh: nil)
      let image = try #require(
        ImageRenderer(content: timeline.frame(width: size.width, height: size.height)).cgImage)
      return try capsuleBands(in: image)
    }
    let withCue = try darkBands(seconds: 1)
    let withoutCue = try darkBands(seconds: 7)
    #expect(withCue.count == 2 && withoutCue.count == 1)
    let badge = try #require(withCue.first)
    let cue = try #require(withCue.last)
    let standaloneCue = FeedbackVideoMarkerCue(
      marker: marker, selected: false, scale: scale, select: { _ in }
    )
    .frame(width: 452 * scale)
    let fullHeight = try #require(ImageRenderer(content: standaloneCue).cgImage?.height)
    #expect(abs(fullHeight - cue.count) <= 2)
    #expect(badge == withoutCue.first)
    #expect(try darkBands(seconds: 1, showsAnnotation: true) == [cue])
    #expect(CGFloat(cue.lowerBound - badge.upperBound) >= 10 * scale - 1)
    let trackAreaTop = size.height - 69 * scale - 22
    #expect(trackAreaTop - CGFloat(cue.upperBound) >= 8 * scale - 1)
  }

  // Scan the semi-transparent black fills, independent of localized glyphs.
  private func capsuleBands(in image: CGImage) throws -> [Range<Int>] {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try pixels.withUnsafeMutableBytes { buffer in
      let context = try #require(
        CGContext(
          data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
          bytesPerRow: 4 * image.width, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    var bands: [Range<Int>] = []
    for y in 0..<image.height {
      let filled = (45..<95).contains { x in
        let index = (y * image.width + x) * 4
        return pixels[index] < 30 && pixels[index + 3] > 80
      }
      guard filled else { continue }
      if let last = bands.last, last.upperBound == y {
        bands[bands.count - 1] = last.lowerBound..<(y + 1)
      } else {
        bands.append(y..<(y + 1))
      }
    }
    return bands
  }
}
