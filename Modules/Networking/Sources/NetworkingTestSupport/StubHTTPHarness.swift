import Foundation
import Networking

public struct StubHTTPResponse: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let body: Data

  public init(
    statusCode: Int = 200,
    headers: [String: String] = ["Content-Type": "application/json"],
    body: Data
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
  }
}

public enum StubHTTPHarnessError: Error, Equatable, Sendable {
  case invalidResponse
  case responseQueueEmpty
  case unregisteredHarness
}

public final class StubHTTPHarness: @unchecked Sendable {
  public var onRequest: (@Sendable (URLRequest) -> Void)? {
    get { state.requestHook() }
    set { state.setRequestHook(newValue) }
  }

  public var transport: APIClient.Transport {
    makeTransport()
  }

  private let identifier: UUID
  private let session: URLSession
  private let state: StubHTTPState

  public init() {
    let identifier = UUID()
    let state = StubHTTPState()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]

    self.identifier = identifier
    self.state = state
    session = URLSession(configuration: configuration)
    StubURLProtocol.register(state, for: identifier)
  }

  deinit {
    session.invalidateAndCancel()
    StubURLProtocol.unregister(identifier)
  }

  public func enqueue(_ response: StubHTTPResponse) {
    state.enqueue(.response(response))
  }

  public func enqueue(
    statusCode: Int = 200,
    headers: [String: String] = ["Content-Type": "application/json"],
    body: Data
  ) {
    enqueue(StubHTTPResponse(statusCode: statusCode, headers: headers, body: body))
  }

  public func enqueue(error: any Error & Sendable) {
    state.enqueue(.failure(error))
  }

  public func makeTransport() -> APIClient.Transport {
    { [self] request in
      var routedRequest = request
      routedRequest.setValue(
        identifier.uuidString,
        forHTTPHeaderField: StubURLProtocol.harnessHeader
      )

      let (data, response) = try await session.data(for: routedRequest)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw StubHTTPHarnessError.invalidResponse
      }
      return APIResponse(data: data, statusCode: httpResponse.statusCode)
    }
  }
}

public final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  fileprivate static let harnessHeader = "X-MeetPR-Stub-Harness"

  private static let registry = StubHTTPRegistry()

  fileprivate static func register(_ state: StubHTTPState, for identifier: UUID) {
    registry.register(state, for: identifier)
  }

  fileprivate static func unregister(_ identifier: UUID) {
    registry.unregister(identifier)
  }

  // URLProtocol requires an overridable class method; an override cannot be static.
  // swiftlint:disable:next static_over_final_class
  public override class func canInit(with request: URLRequest) -> Bool {
    request.value(forHTTPHeaderField: harnessHeader) != nil
  }

  // swiftlint:disable:next static_over_final_class
  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  public override func startLoading() {
    guard
      let rawIdentifier = request.value(forHTTPHeaderField: Self.harnessHeader),
      let identifier = UUID(uuidString: rawIdentifier),
      let state = Self.registry.state(for: identifier)
    else {
      client?.urlProtocol(self, didFailWithError: StubHTTPHarnessError.unregisteredHarness)
      return
    }

    var observedRequest = request
    observedRequest.setValue(nil, forHTTPHeaderField: Self.harnessHeader)

    switch state.dequeue(for: observedRequest) {
    case .response(let response):
      deliver(response)
    case .failure(let error):
      client?.urlProtocol(self, didFailWithError: error)
    case nil:
      client?.urlProtocol(self, didFailWithError: StubHTTPHarnessError.responseQueueEmpty)
    }
  }

  public override func stopLoading() {}

  private func deliver(_ response: StubHTTPResponse) {
    guard
      let url = request.url,
      let httpResponse = HTTPURLResponse(
        url: url,
        statusCode: response.statusCode,
        httpVersion: nil,
        headerFields: response.headers
      )
    else {
      client?.urlProtocol(self, didFailWithError: StubHTTPHarnessError.invalidResponse)
      return
    }

    client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: response.body)
    client?.urlProtocolDidFinishLoading(self)
  }
}

private enum StubHTTPResult: Sendable {
  case response(StubHTTPResponse)
  case failure(any Error & Sendable)
}

private final class StubHTTPState: @unchecked Sendable {
  private let lock = NSLock()
  private var queue: [StubHTTPResult] = []
  private var hook: (@Sendable (URLRequest) -> Void)?

  func enqueue(_ result: StubHTTPResult) {
    lock.lock()
    queue.append(result)
    lock.unlock()
  }

  func requestHook() -> (@Sendable (URLRequest) -> Void)? {
    lock.lock()
    defer { lock.unlock() }
    return hook
  }

  func setRequestHook(_ hook: (@Sendable (URLRequest) -> Void)?) {
    lock.lock()
    self.hook = hook
    lock.unlock()
  }

  func dequeue(for request: URLRequest) -> StubHTTPResult? {
    let hook = requestHook()
    hook?(request)

    lock.lock()
    defer { lock.unlock() }
    guard !queue.isEmpty else {
      return nil
    }
    return queue.removeFirst()
  }
}

private final class StubHTTPRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var states: [UUID: StubHTTPState] = [:]

  func register(_ state: StubHTTPState, for identifier: UUID) {
    lock.lock()
    states[identifier] = state
    lock.unlock()
  }

  func unregister(_ identifier: UUID) {
    lock.lock()
    states[identifier] = nil
    lock.unlock()
  }

  func state(for identifier: UUID) -> StubHTTPState? {
    lock.lock()
    defer { lock.unlock() }
    return states[identifier]
  }
}
