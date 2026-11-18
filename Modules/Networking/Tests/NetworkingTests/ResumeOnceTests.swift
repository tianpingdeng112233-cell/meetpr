import Foundation
import Testing

@testable import Networking

@Suite struct ResumeOnceTests {
  @Test(arguments: [true, false])
  func duplicateCallbacksResumeOnlyOnceAndKeepFirstOutcome(errorFirst: Bool) {
    let recorder = ResultRecorder<Void>()
    let resumer = ResumeOnce<Void> { recorder.record($0) }

    completeTwice(errorFirst: errorFirst) { resumer.resume(with: $0) }

    #expect(recorder.results.count == 1)
    switch recorder.results.first {
    case .success:
      #expect(!errorFirst)
    case .failure(let error):
      #expect(errorFirst)
      #expect((error as? URLError)?.code == .networkConnectionLost)
    case nil:
      Issue.record("Expected a terminal result")
    }
  }

  @Test func concurrentCallbacksResumeOnlyOnce() async {
    let recorder = ResultRecorder<Void>()
    let resumer = ResumeOnce<Void> { recorder.record($0) }

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<100 {
        group.addTask {
          completeTwice(errorFirst: index.isMultiple(of: 2)) { resumer.resume(with: $0) }
        }
      }
    }

    #expect(recorder.results.count == 1)
  }

  @Test(arguments: [true, false])
  func authorizationStartAndCallbackKeepFirstResult(startFails: Bool) throws {
    let callbackURL = try #require(URL(string: "meetpr-test:/callback"))
    let recorder = ResultRecorder<URL>()
    let resumer = ResumeOnce<URL> { recorder.record($0) }

    // A startup failure and a later system callback share the same resumer.
    if startFails { resumer.resume(with: .failure(URLError(.cannotConnectToHost))) }
    resumer.resume(with: .success(callbackURL))
    resumer.resume(with: .failure(URLError(.cancelled)))

    #expect(recorder.results.count == 1)
    let first = try #require(recorder.results.first)
    if startFails {
      guard case .failure(let error) = first else {
        Issue.record("Expected the startup error to win")
        return
      }
      #expect((error as? URLError)?.code == .cannotConnectToHost)
    } else {
      #expect(try first.get() == callbackURL)
    }
  }
}

private final class ResultRecorder<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [Result<Value, any Error>] = []

  var results: [Result<Value, any Error>] {
    lock.withLock { recorded }
  }

  func record(_ result: Result<Value, any Error>) {
    lock.withLock { recorded.append(result) }
  }
}

private func completeTwice(
  errorFirst: Bool,
  completion: @Sendable (Result<Void, any Error>) -> Void
) {
  let failure: Result<Void, any Error> = .failure(URLError(.networkConnectionLost))
  completion(errorFirst ? failure : .success(()))
  completion(errorFirst ? .success(()) : failure)
}
