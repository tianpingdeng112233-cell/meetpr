import Foundation

public struct UploadFailureDestination: Equatable, Hashable, Sendable {
  static let notificationDestination = "failed-video-attachments"
  static let destinationKey = "destination"
  static let setLogIDKey = "setLogID"
  static let trainingDateKey = "trainingDate"

  public let setLogID: UUID
  public let trainingDate: Date

  public init(setLogID: UUID, trainingDate: Date) {
    self.setLogID = setLogID
    self.trainingDate = trainingDate
  }

  public var notificationUserInfo: [String: Any] {
    [
      Self.destinationKey: Self.notificationDestination,
      Self.setLogIDKey: setLogID.uuidString,
      Self.trainingDateKey: trainingDate.timeIntervalSince1970,
    ]
  }

  public init?(notificationUserInfo: [AnyHashable: Any]) {
    guard
      notificationUserInfo[Self.destinationKey] as? String == Self.notificationDestination,
      let setLogIDString = notificationUserInfo[Self.setLogIDKey] as? String,
      let setLogID = UUID(uuidString: setLogIDString),
      let trainingTimestamp = notificationUserInfo[Self.trainingDateKey] as? Double
    else { return nil }
    self.init(
      setLogID: setLogID,
      trainingDate: Date(timeIntervalSince1970: trainingTimestamp)
    )
  }
}

/// Process-local bridge from a tapped upload-failure notification to the
/// existing training-day navigation.
public final class UploadFailureNavigation: @unchecked Sendable {
  public static let shared = UploadFailureNavigation()

  public let events: AsyncStream<UploadFailureDestination>
  private let continuation: AsyncStream<UploadFailureDestination>.Continuation

  private init() {
    let stream = AsyncStream.makeStream(
      of: UploadFailureDestination.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    events = stream.stream
    continuation = stream.continuation
  }

  public func openFailedAttachment(_ destination: UploadFailureDestination) {
    continuation.yield(destination)
  }
}
