import Foundation
import Testing

@testable import Analytics
@testable import StudentKit

@Test("Video failures enqueue only bounded symbolic diagnostics for every stage")
func videoProcessingDiagnosticsPayloads() async throws {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let queue = EventQueueStore(directory: directory)
  let core = AnalyticsCore(queue: queue, installCrashCapture: { _, _ in nil })
  let analytics = Analytics(makeCore: { core })
  analytics.configure(
    baseURL: URL(fileURLWithPath: "/"), transport: { _, _ in throw CancellationError() },
    accessTokenProvider: { nil }, privacyNoticeConfirmed: false)
  let diagnostics = VideoProcessingDiagnostics(analytics: analytics)
  let privateError = NSError(
    domain: NSCocoaErrorDomain, code: 260,
    userInfo: [NSLocalizedDescriptionKey: "/private/student/movie.mov cannot be read"])
  for stage in VideoProcessingStage.allCases {
    diagnostics.report(stage, error: privateError)
  }
  diagnostics.report(.picker, code: .noTransferable)
  diagnostics.report(.trimInfo, code: .invalidSource)
  diagnostics.report(.duration, code: .tooLong)
  diagnostics.report(.export, error: NSError(domain: "/private/movie.mov", code: -9))
  diagnostics.report(.export, error: VideoUploadError.exportFailed("/private/movie.mov secret"))
  for _ in 0..<100 where await queue.count() < 10 {
    try await Task.sleep(for: .milliseconds(10))
  }
  let events = await queue.events()
  #expect(events.count == 10)
  try expectPrivateVideoPayloads(events)
  let codes = Set(
    events.compactMap { event -> String? in
      guard case .enumCase(let code) = event.props["code"] else { return nil }
      return code
    })
  for stage in ["picker", "trim_info", "trim_export", "duration", "export"] {
    #expect(codes.contains("video.\(stage).COCOA_260"))
  }
  #expect(codes.contains("video.picker.NO_TRANSFERABLE"))
  #expect(codes.contains("video.trim_info.INVALID_SOURCE"))
  #expect(codes.contains("video.duration.TOO_LONG"))
  #expect(codes.contains("video.export.UNKNOWN_-9"))
  #expect(codes.contains("video.export.EXPORT_FAILED"))
}

@Test("Cancellation and failures after dismissal do not enqueue video diagnostics")
func videoProcessingDiagnosticsIgnoreCancellation() async throws {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let queue = EventQueueStore(directory: directory)
  let core = AnalyticsCore(queue: queue, installCrashCapture: { _, _ in nil })
  let analytics = Analytics(makeCore: { core })
  analytics.configure(
    baseURL: URL(fileURLWithPath: "/"), transport: { _, _ in throw CancellationError() },
    accessTokenProvider: { nil }, privacyNoticeConfirmed: false)
  let diagnostics = VideoProcessingDiagnostics(analytics: analytics)
  diagnostics.report(.picker, error: CancellationError())
  diagnostics.report(
    .trimExport, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
  diagnostics.report(.picker, code: .noTransferable, isActive: false)
  let task = Task {
    withUnsafeCurrentTask { $0?.cancel() }
    diagnostics.report(.export, error: VideoUploadError.exportFailed("late"))
  }
  await task.value
  // A following event is the queue barrier; cancelled calls must add nothing.
  diagnostics.report(.picker, code: .noTransferable)
  for _ in 0..<100 where await queue.count() < 1 {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(await queue.count() == 1)
}

@Test(
  "Picker error domains use fixed symbols without exposing private details",
  arguments: [
    ("CoreTransferable.TransferableSupportError", "TRANSFER"),
    ("PHPhotosErrorDomain", "PHOTOS"),
    ("NSItemProviderErrorDomain", "ITEMPROVIDER"),
    ("CloudPhotoLibraryErrorDomain", "CLOUDPHOTO"),
    ("/private/movie.mov secret", "UNKNOWN"),
  ])
func videoProcessingDiagnosticsPickerDomains(domain: String, symbol: String) async throws {
  let error = NSError(
    domain: domain, code: -9,
    userInfo: [NSLocalizedDescriptionKey: "/private/movie.mov secret"])
  let event = try await recordedVideoDiagnostic(error)
  #expect(event.props["code"] == .enumCase("video.picker.\(symbol)_-9"))
}

@Test(
  "Picker diagnostics include only one sanitized underlying error",
  arguments: [("PHPhotosErrorDomain", "PHOTOS"), ("/private/movie.mov secret", "UNKNOWN")])
func videoProcessingDiagnosticsUnderlyingError(domain: String, symbol: String) async throws {
  let underlying = NSError(
    domain: domain, code: -1,
    userInfo: [
      NSLocalizedDescriptionKey: "/private/movie.mov secret",
      NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: -1009),
    ])
  let error = NSError(
    domain: "CoreTransferable.TransferableSupportError", code: 0,
    userInfo: [NSUnderlyingErrorKey: underlying])
  let event = try await recordedVideoDiagnostic(error)
  #expect(event.props["code"] == .enumCase("video.picker.TRANSFER_0.\(symbol)_-1"))
}

@Test(
  "Diagnostics retain the top-level error when its underlying segment exceeds 64 characters",
  arguments: [
    (
      VideoProcessingStage.picker, 12_345_678_901,
      "video.picker.ITEMPROVIDER_9223372036854775807.PHOTOS_12345678901"
    ),
    (.picker, 123_456_789_012, "video.picker.ITEMPROVIDER_9223372036854775807"),
    (.trimExport, 12_345_678_901, "video.trim_export.ITEMPROVIDER_9223372036854775807"),
    (.picker, Int.min, "video.picker.ITEMPROVIDER_9223372036854775807"),
  ])
func videoProcessingDiagnosticsCodeLength(
  stage: VideoProcessingStage, underlyingCode: Int, expectedCode: String
) async throws {
  let error = NSError(
    domain: "NSItemProviderErrorDomain", code: Int.max,
    userInfo: [
      NSUnderlyingErrorKey: NSError(domain: "PHPhotosErrorDomain", code: underlyingCode)
    ])
  let event = try await recordedVideoDiagnostic(error, stage: stage)
  #expect(event.props["code"] == .enumCase(expectedCode))
}

private func recordedVideoDiagnostic(
  _ error: NSError, stage: VideoProcessingStage = .picker
) async throws -> AnalyticsEnvelope {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let queue = EventQueueStore(directory: directory)
  let core = AnalyticsCore(queue: queue, installCrashCapture: { _, _ in nil })
  let analytics = Analytics(makeCore: { core })
  analytics.configure(
    baseURL: URL(fileURLWithPath: "/"), transport: { _, _ in throw CancellationError() },
    accessTokenProvider: { nil }, privacyNoticeConfirmed: false)
  VideoProcessingDiagnostics(analytics: analytics).report(stage, error: error)
  for _ in 0..<100 where await queue.count() < 1 {
    try await Task.sleep(for: .milliseconds(10))
  }
  let events = await queue.events()
  #expect(events.count == 1)
  try expectPrivateVideoPayloads(events)
  return try #require(events.first)
}

private func expectPrivateVideoPayloads(_ events: [AnalyticsEnvelope]) throws {
  for event in events {
    #expect(event.name == .clientError)
    #expect(Set(event.props.keys) == ["domain", "code", "screen"])
    #expect(event.props["domain"] == .enumCase("decode"))
    #expect(event.props["screen"] == .enumCase("today_workout"))
    let data = try JSONEncoder().encode(event.props)
    let encoded = try #require(String(data: data, encoding: .utf8))
    #expect(!encoded.contains("private"))
    #expect(!encoded.contains("secret"))
    guard case .enumCase(let code) = event.props["code"] else {
      Issue.record("Expected a symbolic code")
      continue
    }
    #expect(code.range(of: "^[A-Za-z0-9_.-]{1,64}$", options: .regularExpression) != nil)
  }
}
