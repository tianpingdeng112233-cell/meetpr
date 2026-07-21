import Foundation

extension Error {
  var isChatTaskCancellation: Bool {
    if self is CancellationError {
      return true
    }
    if let urlError = self as? URLError, urlError.code == .cancelled {
      return true
    }
    return false
  }
}
