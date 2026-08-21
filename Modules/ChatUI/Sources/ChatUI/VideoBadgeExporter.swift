import AVFoundation
import CoreMedia
import DesignSystem
import Foundation
import QuartzCore
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeExporter {
  func export(sourceURL: URL, badge: VideoBadgeInfo) async throws -> URL {
    let source = AVURLAsset(url: sourceURL)
    let duration = try await source.load(.duration)
    guard duration.isNumeric, duration.seconds > 0 else {
      throw VideoBadgeExportError.invalidSource
    }
    guard let sourceVideoTrack = try await source.loadTracks(withMediaType: .video).first else {
      throw VideoBadgeExportError.missingVideoTrack
    }
    let sourceRange = CMTimeRange(start: .zero, duration: duration)
    let prepared = try await makeComposition(
      source: source,
      sourceVideoTrack: sourceVideoTrack,
      sourceRange: sourceRange
    )
    let videoComposition = try await makeVideoComposition(
      sourceVideoTrack: sourceVideoTrack,
      composition: prepared.asset,
      compositionVideoTrack: prepared.videoTrack,
      sourceRange: sourceRange,
      badge: badge
    )

    guard
      let exportSession = AVAssetExportSession(
        asset: prepared.asset,
        presetName: AVAssetExportPresetHighestQuality
      )
    else {
      throw VideoBadgeExportError.cannotCreateExportSession
    }
    exportSession.videoComposition = videoComposition
    exportSession.shouldOptimizeForNetworkUse = true

    let output = try Self.output(for: exportSession)
    do {
      try await VideoBadgeExportCoordinator(
        session: exportSession,
        outputURL: output.url,
        outputType: output.type
      ).run()
      return output.url
    } catch {
      try? FileManager.default.removeItem(at: output.url)
      throw error
    }
  }

  private func makeComposition(
    source: AVURLAsset,
    sourceVideoTrack: AVAssetTrack,
    sourceRange: CMTimeRange
  ) async throws -> VideoBadgeComposition {
    let composition = AVMutableComposition()
    guard
      let compositionVideoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
    else {
      throw VideoBadgeExportError.cannotCreateComposition
    }
    try compositionVideoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: .zero)

    for sourceAudioTrack in try await source.loadTracks(withMediaType: .audio) {
      guard
        let compositionAudioTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else {
        throw VideoBadgeExportError.cannotCreateComposition
      }
      try compositionAudioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: .zero)
    }
    return VideoBadgeComposition(asset: composition, videoTrack: compositionVideoTrack)
  }

  private func makeVideoComposition(
    sourceVideoTrack: AVAssetTrack,
    composition: AVMutableComposition,
    compositionVideoTrack: AVMutableCompositionTrack,
    sourceRange: CMTimeRange,
    badge: VideoBadgeInfo
  ) async throws -> AVMutableVideoComposition {
    let geometry = Self.renderGeometry(
      naturalSize: try await sourceVideoTrack.load(.naturalSize),
      preferredTransform: try await sourceVideoTrack.load(.preferredTransform)
    )
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(
      assetTrack: compositionVideoTrack
    )
    layerInstruction.setTransform(geometry.transform, at: .zero)
    let badgeTrackID = composition.unusedTrackID()
    let badgeLayerInstruction = AVMutableVideoCompositionLayerInstruction()
    badgeLayerInstruction.trackID = badgeTrackID

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = sourceRange
    instruction.layerInstructions = [badgeLayerInstruction, layerInstruction]

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = geometry.renderSize
    videoComposition.frameDuration = try await Self.frameDuration(for: sourceVideoTrack)
    videoComposition.instructions = [instruction]
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
      additionalLayer: try makeBadgeLayer(badge: badge, renderSize: geometry.renderSize),
      asTrackID: badgeTrackID
    )
    return videoComposition
  }

  static func renderGeometry(
    naturalSize: CGSize,
    preferredTransform: CGAffineTransform
  ) -> VideoBadgeRenderGeometry {
    let transformedBounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
    let renderSize = CGSize(
      width: ceil(abs(transformedBounds.width)),
      height: ceil(abs(transformedBounds.height))
    )
    let normalization = CGAffineTransform(
      translationX: -transformedBounds.minX,
      y: -transformedBounds.minY
    )
    return VideoBadgeRenderGeometry(
      renderSize: renderSize,
      transform: preferredTransform.concatenating(normalization)
    )
  }

  private static func frameDuration(for track: AVAssetTrack) async throws -> CMTime {
    let minimum = try await track.load(.minFrameDuration)
    if minimum.isNumeric, minimum.seconds > 0 {
      return minimum
    }
    let nominalFrameRate = try await track.load(.nominalFrameRate)
    let timeScale = CMTimeScale(max(1, nominalFrameRate.rounded()))
    return CMTime(value: 1, timescale: timeScale)
  }

  private func makeBadgeLayer(
    badge: VideoBadgeInfo,
    renderSize: CGSize
  ) throws -> sending CALayer {
    let cardWidth = VideoBadgeLayout.exportCardWidth(renderWidth: renderSize.width)
    let renderer = ImageRenderer(
      content: ZStack(alignment: .bottom) {
        Color.clear
        VideoBadgeCard(
          presentation: VideoBadgePresentation(info: badge),
          width: cardWidth,
          includesCoachAttribution: true
        )
        .padding(.bottom, VideoBadgeLayout.exportBottomMargin(renderHeight: renderSize.height))
      }
      .frame(width: renderSize.width, height: renderSize.height)
      .environment(\.colorScheme, .dark)
    )
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(renderSize)
    guard let overlayImage = renderer.cgImage else {
      throw VideoBadgeExportError.cannotRenderBadge
    }

    let overlayLayer = CALayer()
    overlayLayer.contents = overlayImage
    overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
    return overlayLayer
  }

  private static func output(
    for session: AVAssetExportSession
  ) throws -> (url: URL, type: AVFileType) {
    let type: AVFileType
    let pathExtension: String
    if session.supportedFileTypes.contains(.mov) {
      type = .mov
      pathExtension = "mov"
    } else if session.supportedFileTypes.contains(.mp4) {
      type = .mp4
      pathExtension = "mp4"
    } else {
      throw VideoBadgeExportError.unsupportedOutputType
    }
    return (
      FileManager.default.temporaryDirectory.appending(
        path: "meetpr-badged-video-\(UUID().uuidString).\(pathExtension)"
      ),
      type
    )
  }
}

private struct VideoBadgeComposition {
  let asset: AVMutableComposition
  let videoTrack: AVMutableCompositionTrack
}

struct VideoBadgeRenderGeometry: Equatable, Sendable {
  let renderSize: CGSize
  let transform: CGAffineTransform
}

enum VideoBadgeExportError: Error, Equatable, Sendable {
  case cannotCreateComposition
  case cannotCreateExportSession
  case cannotRenderBadge
  case exportFailed
  case invalidSource
  case missingVideoTrack
  case unsupportedOutputType
}

private final class VideoBadgeExportCoordinator: @unchecked Sendable {
  private let session: AVAssetExportSession
  private let outputURL: URL
  private let outputType: AVFileType

  init(session: AVAssetExportSession, outputURL: URL, outputType: AVFileType) {
    self.session = session
    self.outputURL = outputURL
    self.outputType = outputType
  }

  func run() async throws {
    try await withTaskCancellationHandler {
      if #available(iOS 18.0, macOS 15.0, *) {
        try await session.export(to: outputURL, as: outputType)
      } else {
        try await runLegacyExport()
      }
    } onCancel: {
      session.cancelExport()
    }
  }

  @available(iOS, introduced: 17.0, obsoleted: 18.0)
  @available(macOS, introduced: 14.0, obsoleted: 15.0)
  private func runLegacyExport() async throws {
    session.outputURL = outputURL
    session.outputFileType = outputType
    await session.export()
    switch session.status {
    case .completed:
      return
    case .cancelled:
      throw CancellationError()
    default:
      throw session.error ?? VideoBadgeExportError.exportFailed
    }
  }
}
