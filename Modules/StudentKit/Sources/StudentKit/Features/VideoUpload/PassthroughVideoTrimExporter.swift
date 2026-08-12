import AVFoundation
import CoreMedia
import Foundation

protocol VideoTrimExporting: Sendable {
  func export(sourceURL: URL, selection: VideoTrimSelection) async throws -> URL
}

struct PassthroughVideoTrimExporter: VideoTrimExporting {
  func export(sourceURL: URL, selection: VideoTrimSelection) async throws -> URL {
    guard selection.isValid else { throw VideoTrimExportError.invalidSelection }

    let asset = AVURLAsset(url: sourceURL)
    let duration = try await asset.load(.duration)
    guard duration.isNumeric, duration.seconds > 0 else {
      throw VideoTrimExportError.invalidSource
    }
    let sourceDurationSeconds = duration.seconds
    guard selection.startSeconds < sourceDurationSeconds else {
      throw VideoTrimExportError.invalidSelection
    }
    let endSeconds = min(selection.endSeconds, sourceDurationSeconds)
    guard endSeconds > selection.startSeconds else {
      throw VideoTrimExportError.invalidSelection
    }
    guard
      let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetPassthrough
      )
    else {
      throw VideoTrimExportError.cannotCreateSession
    }

    let outputType = try Self.outputType(for: exportSession)
    let outputURL = FileManager.default.temporaryDirectory.appending(
      path: "meetpr-video-trim-\(UUID().uuidString).\(outputType.pathExtension)"
    )
    exportSession.timeRange = CMTimeRange(
      start: CMTime(seconds: selection.startSeconds, preferredTimescale: 600),
      end: CMTime(seconds: endSeconds, preferredTimescale: 600)
    )
    exportSession.shouldOptimizeForNetworkUse = true

    do {
      try await VideoTrimExportCoordinator(
        session: exportSession,
        outputURL: outputURL,
        outputType: outputType.fileType
      ).run()
      return outputURL
    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }

  private static func outputType(
    for session: AVAssetExportSession
  ) throws -> (fileType: AVFileType, pathExtension: String) {
    if session.supportedFileTypes.contains(.mov) {
      return (.mov, "mov")
    }
    if session.supportedFileTypes.contains(.mp4) {
      return (.mp4, "mp4")
    }
    throw VideoTrimExportError.unsupportedOutputType
  }
}

private final class VideoTrimExportCoordinator: @unchecked Sendable {
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
      throw session.error ?? VideoTrimExportError.exportFailed
    }
  }
}

private enum VideoTrimExportError: Error {
  case cannotCreateSession
  case exportFailed
  case invalidSelection
  case invalidSource
  case unsupportedOutputType
}

extension AVFileType {
  fileprivate var pathExtension: String {
    switch self {
    case .mov: "mov"
    case .mp4: "mp4"
    default: "mov"
    }
  }
}
