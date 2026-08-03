import AVFoundation
import Foundation

struct AssetWriterStream: @unchecked Sendable {
  let input: AVAssetWriterInput
  let output: AVAssetReaderOutput
  let label: String
}

/// Owns AVFoundation's callback-based transfer loop and narrows its unchecked
/// Sendable crossing to objects whose documented cancellation APIs are thread-safe.
final class AssetWriterCoordinator: @unchecked Sendable {
  private let reader: AVAssetReader
  private let writer: AVAssetWriter
  private let streams: [AssetWriterStream]
  private let lock = NSLock()
  private let transferQueue = DispatchQueue(label: "com.meetpr.video-export")
  private var continuation: CheckedContinuation<Void, any Error>?
  private var finishedStreams: Set<ObjectIdentifier> = []
  private var isFinished = false
  private var isFinishingWriter = false
  private var isCancelled = false
  private var writerHasStarted = false
  private var readerHasStarted = false

  init(reader: AVAssetReader, writer: AVAssetWriter, streams: [AssetWriterStream]) {
    self.reader = reader
    self.writer = writer
    self.streams = streams
  }

  func run() async throws {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withCheckedThrowingContinuation { continuation in
        install(continuation)
      }
    } onCancel: {
      cancel()
    }
  }

  private func install(_ continuation: CheckedContinuation<Void, any Error>) {
    lock.lock()
    if isCancelled {
      lock.unlock()
      continuation.resume(throwing: CancellationError())
      return
    }
    self.continuation = continuation
    let writerStarted = writer.startWriting()
    writerHasStarted = writerStarted
    let readerStarted = writerStarted && reader.startReading()
    readerHasStarted = readerStarted
    if readerStarted { writer.startSession(atSourceTime: .zero) }
    lock.unlock()

    guard writerStarted else {
      fail("Unable to start the asset writer", underlying: writer.error)
      return
    }
    guard readerStarted else {
      fail("Unable to start the asset reader", underlying: reader.error)
      return
    }

    for stream in streams {
      stream.input.requestMediaDataWhenReady(on: transferQueue) { [weak self] in
        self?.transfer(stream)
      }
    }
  }

  private func transfer(_ stream: AssetWriterStream) {
    while stream.input.isReadyForMoreMediaData {
      guard !finished, !cancellationRequested else { return }
      guard let sampleBuffer = stream.output.copyNextSampleBuffer() else {
        stream.input.markAsFinished()
        streamDidFinish(stream)
        return
      }
      guard stream.input.append(sampleBuffer) else {
        fail("Unable to append a \(stream.label) sample", underlying: writer.error)
        return
      }
    }
  }

  private func streamDidFinish(_ stream: AssetWriterStream) {
    let streamID = ObjectIdentifier(stream.input)
    lock.lock()
    let inserted = finishedStreams.insert(streamID).inserted
    let shouldFinishWriter =
      inserted && finishedStreams.count == streams.count && !isFinished && !isFinishingWriter
    if shouldFinishWriter { isFinishingWriter = true }
    lock.unlock()
    guard shouldFinishWriter else { return }

    switch reader.status {
    case .completed:
      writer.finishWriting { [weak self] in
        self?.writerDidFinish()
      }
    case .cancelled:
      cancel()
    default:
      fail("Asset reader did not complete", underlying: reader.error)
    }
  }

  private func writerDidFinish() {
    switch writer.status {
    case .completed:
      complete(with: .success(()))
    case .cancelled:
      complete(with: .failure(CancellationError()))
    default:
      fail("Asset writer did not complete", underlying: writer.error)
    }
  }

  private var finished: Bool {
    lock.withLock { isFinished }
  }

  private var cancellationRequested: Bool {
    lock.withLock { isCancelled }
  }

  private func cancel() {
    let action = lock.withLock {
      guard !isCancelled else { return CancellationAction.none }
      isCancelled = true
      return writerHasStarted
        ? CancellationAction.cancelAVFoundation(readerStarted: readerHasStarted)
        : .complete
    }
    switch action {
    case .cancelAVFoundation(let readerStarted):
      transferQueue.async { [self] in
        if readerStarted { reader.cancelReading() }
        writer.cancelWriting()
        complete(with: .failure(CancellationError()))
      }
    case .complete:
      complete(with: .failure(CancellationError()))
    case .none:
      break
    }
  }

  private func fail(_ message: String, underlying: (any Error)?) {
    let reason = underlying.map { "\(message): \($0.localizedDescription)" } ?? message
    let startedState = lock.withLock { (writerHasStarted, readerHasStarted) }
    guard startedState.0 else {
      complete(with: .failure(VideoUploadError.exportFailed(reason)))
      return
    }
    transferQueue.async { [self] in
      if startedState.1 { reader.cancelReading() }
      writer.cancelWriting()
      complete(with: .failure(VideoUploadError.exportFailed(reason)))
    }
  }

  private func complete(with result: Result<Void, any Error>) {
    // The final state is decided under the same lock that guards
    // `isCancelled`: a cancel that lost the race against a concurrent
    // `finishWriting` success must still surface as cancellation, so the
    // exporter deletes the output instead of returning a cancelled file.
    let resolution = lock.withLock { () -> Resolution? in
      guard !isFinished else { return nil }
      isFinished = true
      defer { continuation = nil }
      return Resolution(
        continuation: continuation,
        result: Self.finalResult(result, isCancelled: isCancelled)
      )
    }
    guard let resolution else { return }
    resolution.continuation?.resume(with: resolution.result)
  }

  static func finalResult(
    _ result: Result<Void, any Error>,
    isCancelled: Bool
  ) -> Result<Void, any Error> {
    guard isCancelled, case .success = result else { return result }
    return .failure(CancellationError())
  }
}

private struct Resolution {
  let continuation: CheckedContinuation<Void, any Error>?
  let result: Result<Void, any Error>
}

private enum CancellationAction {
  case cancelAVFoundation(readerStarted: Bool)
  case complete
  case none
}

extension NSLock {
  fileprivate func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
    lock()
    defer { unlock() }
    return try body()
  }
}
