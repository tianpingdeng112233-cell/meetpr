import CoreModels
import Foundation
import Networking

/// A prior accepted binding only unlocks already-cached training on transport
/// failure. Server responses always win; this never establishes a new binding.
@MainActor struct BindOfflineRecovery {
  let studentID: UUID
  let defaults: UserDefaults
  let hasCachedTraining: @MainActor @Sendable () async -> Bool

  private var key: String { "meetpr.bind.offline.\(studentID.uuidString)" }

  func remember(_ request: BindRequest?) {
    guard let request, request.studentId == studentID,
      request.status == .accepted, request.endedAt == nil,
      let data = try? JSONEncoder().encode(request)
    else {
      defaults.removeObject(forKey: key)
      return
    }
    defaults.set(data, forKey: key)
  }

  func restore(after error: any Error) async -> BindRequest? {
    guard let network = error as? URLError,
      [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
      ].contains(network.code),
      let data = defaults.data(forKey: key),
      let request = try? JSONDecoder().decode(BindRequest.self, from: data),
      request.studentId == studentID, request.status == .accepted, request.endedAt == nil,
      await hasCachedTraining()
    else { return nil }
    return request
  }

  func invalidateIfUnauthorized(_ error: any Error) {
    switch error {
    case APIError.authInvalid,
      APIError.httpStatus(401, _), APIError.httpStatus(403, _),
      APIClientError.httpStatus(401, _), APIClientError.httpStatus(403, _):
      defaults.removeObject(forKey: key)
    default: break
    }
  }
}
