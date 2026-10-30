import Foundation
import Networking
import SwiftUI
import Testing
import ViewInspector

@testable import AppShell

@MainActor
@Test(arguments: ["belowMinimum", "current", "timeout", "http", "malformed", "negative"])
func minimumVersionGateShowsAppUntilResponse(outcome: String) async throws {
  let started = AsyncStream<Void>.makeStream()
  let response = AsyncStream<Void>.makeStream()
  let api = APIClient(transport: { _ in
    started.continuation.yield(())
    for await _ in response.stream { break }
    if outcome == "timeout" { throw URLError(.timedOut) }
    let payload: String
    switch outcome {
    case "belowMinimum": payload = #"{"min_build":29}"#
    case "current": payload = #"{"min_build":28}"#
    case "negative": payload = #"{"min_build":-1}"#
    default: payload = "{}"
    }
    return APIResponse(data: Data(payload.utf8), statusCode: outcome == "http" ? 503 : 200)
  })
  let model = MinimumVersionGateModel(api: api, currentBuild: 28)
  let gate = MinimumVersionGate(model: model) { Text("App content") }

  #expect((try? gate.body.inspect().find(text: "App content")) != nil)
  let check = Task { await model.check() }
  for await _ in started.stream { break }
  #expect((try? gate.body.inspect().find(text: "App content")) != nil)
  #expect((try? gate.body.inspect().find(RequiredAppUpdateView.self)) == nil)

  response.continuation.yield(())
  response.continuation.finish()
  started.continuation.finish()
  await check.value

  if outcome == "belowMinimum" {
    #expect((try? gate.body.inspect().find(text: "App content")) == nil)
    #expect(
      try gate.body.inspect().find(RequiredAppUpdateView.self).actualView().minimumBuild == 29)
    await model.check()
    #expect(
      try gate.body.inspect().find(RequiredAppUpdateView.self).actualView().minimumBuild == 29)
  } else {
    #expect((try? gate.body.inspect().find(text: "App content")) != nil)
    #expect((try? gate.body.inspect().find(RequiredAppUpdateView.self)) == nil)
  }
}
