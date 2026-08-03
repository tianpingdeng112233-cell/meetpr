import Foundation

enum DashboardDayShiftAlert: Identifiable {
  case confirmCancel(Date)
  case message(title: String, text: String)

  var id: String {
    switch self {
    case .confirmCancel(let date): "cancel-\(date.timeIntervalSince1970)"
    case .message(let title, let text): "message-\(title)-\(text)"
    }
  }
}
