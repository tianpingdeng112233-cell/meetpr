import Foundation
import Observation

/// Session-only image dimensions survive view recreation and signed URL renewal.
@MainActor @Observable
public final class ChatVideoPosterDimensions {
  public static let shared = ChatVideoPosterDimensions()
  private var sizes: [UUID: CGSize] = [:]

  public init() {}

  public func imageSize(for videoID: UUID) -> CGSize? {
    sizes[videoID]
  }

  public func remember(_ size: CGSize?, for videoID: UUID) {
    sizes[videoID] = size
  }
}
