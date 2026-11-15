import Analytics
import Foundation

// Matches Android's video.<stage>.<symbol> namespace and the server's strict
// client_error contract. Neither NSError domains nor descriptions leave here.
enum VideoProcessingStage: String, CaseIterable, Sendable {
  case picker
  case trimInfo = "trim_info"
  case trimExport = "trim_export"
  case duration
  case export
}

struct VideoProcessingDiagnostics: Sendable {
  enum Code: String {
    case noTransferable = "NO_TRANSFERABLE"
    case invalidSource = "INVALID_SOURCE"
    case tooLong = "TOO_LONG"
  }

  var analytics: Analytics = .shared

  func report(_ stage: VideoProcessingStage, code: Code, isActive: Bool = true) {
    guard isActive, !Task.isCancelled else { return }
    enqueue(stage, code: code.rawValue)
  }

  func report(_ stage: VideoProcessingStage, error: Error, isActive: Bool = true) {
    guard isActive, !Task.isCancelled, !Self.isCancellation(error) else { return }
    var code: String
    if case VideoUploadError.exportFailed = error {
      code = "EXPORT_FAILED"
    } else if case VideoUploadError.durationExceedsLimit = error {
      code = Code.tooLong.rawValue
    } else {
      let native = error as NSError
      code = Self.symbolicCode(native)
      if let underlying = native.userInfo[NSUnderlyingErrorKey] as? NSError {
        let combined = "\(code).\(Self.symbolicCode(underlying))"
        if "video.\(stage.rawValue).\(combined)".count <= 64 {
          code = combined
        }
      }
    }
    enqueue(stage, code: code)
  }

  static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    let native = error as NSError
    return (native.domain == NSURLErrorDomain && native.code == NSURLErrorCancelled)
      || (native.domain == NSCocoaErrorDomain && native.code == NSUserCancelledError)
      || (native.domain == "AVFoundationErrorDomain" && native.code == -11878)
  }

  private static func symbolicCode(_ error: NSError) -> String {
    let domain: String
    switch error.domain {
    case NSCocoaErrorDomain: domain = "COCOA"
    case NSURLErrorDomain: domain = "URL"
    case "AVFoundationErrorDomain": domain = "AV"
    case NSOSStatusErrorDomain: domain = "OSSTATUS"
    case "CoreTransferable.TransferableSupportError": domain = "TRANSFER"
    case "PHPhotosErrorDomain": domain = "PHOTOS"
    case "NSItemProviderErrorDomain": domain = "ITEMPROVIDER"
    case "CloudPhotoLibraryErrorDomain": domain = "CLOUDPHOTO"
    default: domain = "UNKNOWN"
    }
    return "\(domain)_\(error.code)"
  }

  private func enqueue(_ stage: VideoProcessingStage, code: String) {
    analytics.track(
      .clientError,
      props: [
        "domain": .enumCase(ClientErrorDomain.decode),
        "code": .enumCase("video.\(stage.rawValue).\(code)"),
        "screen": .enumCase(AnalyticsScreen.todayWorkout),
      ])
  }
}

// Keep the existing duration rejection and file ownership semantics; only
// observe metadata-read failures that occur before the upload export starts.
extension VideoUploadManager {
  func diagnosedDuration(of sourceURL: URL) async throws -> Double {
    do {
      return try await exporter.durationSeconds(of: sourceURL)
    } catch {
      VideoProcessingDiagnostics().report(.duration, error: error)
      throw error
    }
  }
}
