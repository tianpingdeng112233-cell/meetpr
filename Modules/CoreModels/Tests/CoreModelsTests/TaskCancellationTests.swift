import Foundation
import Testing

@testable import CoreModels

@Test func taskCancellationRecognizesSwiftAndURLSessionErrors() {
  #expect(CancellationError().isTaskCancellation)
  #expect(URLError(.cancelled).isTaskCancellation)
  #expect(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled).isTaskCancellation)
  #expect(!URLError(.timedOut).isTaskCancellation)
  #expect(!NSError(domain: "app.failure", code: NSURLErrorCancelled).isTaskCancellation)
}
