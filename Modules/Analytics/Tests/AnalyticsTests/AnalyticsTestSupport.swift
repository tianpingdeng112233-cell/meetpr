import Foundation

@testable import Analytics

func makeTemporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

func makeEvent(
  id: UUID = UUID(),
  seq: Int = 0,
  name: AnalyticsEvent = .appOpen,
  timestamp: Date = Date()
) -> AnalyticsEnvelope {
  AnalyticsEnvelope(
    eventID: id,
    sessionID: UUID(),
    seq: seq,
    name: name,
    props: [:],
    schemaVersion: 1,
    timestamp: timestamp
  )
}

func makeHTTPResponse(
  status: Int,
  url: URL = URL(string: "https://example.com") ?? URL(fileURLWithPath: "/")
) throws -> HTTPURLResponse {
  guard
    let response = HTTPURLResponse(
      url: url, statusCode: status, httpVersion: nil, headerFields: nil)
  else {
    throw AnalyticsTestSupportError.invalidHTTPResponse
  }
  return response
}

enum AnalyticsTestSupportError: Error {
  case invalidHTTPResponse
}

final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) {
    self.value = value
  }

  func now() -> Date {
    lock.withLock { value }
  }

  func advance(by interval: TimeInterval) {
    lock.withLock { value = value.addingTimeInterval(interval) }
  }
}

actor RequestRecorder {
  private(set) var requests: [(URLRequest, Data)] = []

  func append(_ request: URLRequest, body: Data) {
    requests.append((request, body))
  }

  func count() -> Int { requests.count }

  func snapshot() -> [(URLRequest, Data)] { requests }
}
