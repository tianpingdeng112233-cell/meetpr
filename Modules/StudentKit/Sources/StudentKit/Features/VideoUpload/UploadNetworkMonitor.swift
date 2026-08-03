import Foundation
import Network

final class UploadNetworkMonitor: UploadNetworkMonitoring, @unchecked Sendable {
  let updates: AsyncStream<Bool>

  private let monitor: NWPathMonitor
  private let continuation: AsyncStream<Bool>.Continuation

  init() {
    monitor = NWPathMonitor()
    let stream = AsyncStream.makeStream(of: Bool.self, bufferingPolicy: .bufferingNewest(1))
    updates = stream.stream
    continuation = stream.continuation
    monitor.pathUpdateHandler = { [continuation] path in
      continuation.yield(path.status == .satisfied)
    }
    monitor.start(queue: DispatchQueue(label: "com.meetpr.video-upload-network"))
  }

  deinit {
    monitor.cancel()
    continuation.finish()
  }
}

protocol UploadNetworkMonitoring: Sendable {
  var updates: AsyncStream<Bool> { get }
}
