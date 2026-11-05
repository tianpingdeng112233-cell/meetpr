import CoreModels
import Foundation

extension BindGateViewModel {
  /// D8 mapping: rejected → neutral "not accepting"; expired → expired copy;
  /// Coach-ended bindings → unlink copy; withdrawn requests / no history → no notice.
  static func notice(for request: BindRequest?) -> BindNotice? {
    switch request?.status {
    case .rejected: return .coachNotAccepting
    case .expired: return .requestExpired
    case .cancelled:
      if let request, request.endedAt != nil {
        let name = request.coachDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .coachUnlinked(coachDisplayName: name?.isEmpty == false ? name : nil)
      } else {
        return nil
      }
    case .pending, .accepted, .none: return nil
    }
  }
}
