import CoreModels
import Foundation

public struct ChatSetCardPresentation: Equatable, Sendable {
  let source: SetRefSource
  let exerciseName: String
  let setNumber: Int
  let setTotal: Int?
  let weight: String
  let reps: String
  let rpe: String?
  let createdAt: Date
  let note: String?
  let videoURL: URL?

  public init?(message: ChatMessage) {
    guard
      message.kind == .text,
      let setRef = message.setRef,
      let body = message.text
    else {
      return nil
    }

    let firstLine = SetRefCanonicalFormatter.firstLine(for: setRef)
    let note: String?
    if body == firstLine {
      note = nil
    } else {
      let prefix = "\(firstLine)\n"
      guard body.hasPrefix(prefix) else {
        return nil
      }
      // Three states, matching plan-web: nil = no newline, "" = explicitly empty remark,
      // non-empty = remark. The view filters the empty string; the model must not collapse it.
      note = String(body.dropFirst(prefix.count))
    }

    source = setRef.source
    exerciseName = setRef.exerciseName
    setNumber = setRef.setNumber
    setTotal = setRef.setTotal
    weight = setRef.weightKg ?? "-"
    if let lowerBound = setRef.reps, let upperBound = setRef.repsMax {
      reps = "\(lowerBound)-\(upperBound)"
    } else {
      reps = setRef.reps.map(String.init) ?? "-"
    }
    rpe = setRef.rpe
    createdAt = message.createdAt
    self.note = note
    videoURL = message.videoURL.flatMap { $0.absoluteString.isEmpty ? nil : $0 }
  }
}

enum ChatSetCardDeliveryPresentation {
  static func text(for status: ChatDeliveryStatus) -> String {
    switch status {
    case .delivered:
      ChatStrings.setCardDelivered
    case .read:
      ChatStrings.setCardRead
    }
  }
}
