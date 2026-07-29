import CoreModels
import Foundation

public struct SetRefShareVideo: Sendable {
  public enum State: Equatable, Sendable {
    case uploading
    case ready
    case failed
  }

  public let state: State
  private let resolve: @Sendable () async -> SetRefVideoSelection?

  public init(
    state: State,
    resolve: @escaping @Sendable () async -> SetRefVideoSelection?
  ) {
    self.state = state
    self.resolve = resolve
  }

  public func selection() async -> SetRefVideoSelection? {
    await resolve()
  }
}

public struct SetRefShareCandidate: Identifiable, Sendable {
  public let id: UUID
  public let source: SetRefSourceSnapshot
  public let video: SetRefShareVideo?

  public init(
    id: UUID,
    source: SetRefSourceSnapshot,
    video: SetRefShareVideo? = nil
  ) {
    self.id = id
    self.source = source
    self.video = video
  }
}

public struct SetRefSharingContext: Sendable {
  private let load: @Sendable () async throws -> [SetRefShareCandidate]

  public init(
    load: @escaping @Sendable () async throws -> [SetRefShareCandidate]
  ) {
    self.load = load
  }

  public func candidates() async throws -> [SetRefShareCandidate] {
    try await load()
  }
}
