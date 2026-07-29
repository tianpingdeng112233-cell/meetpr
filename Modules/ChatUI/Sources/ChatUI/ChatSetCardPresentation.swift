import CoreModels
import Foundation

public struct ChatSetCardPresentation: Equatable, Sendable {
  let exerciseName: String
  let setNumber: Int
  let load: String
  let rpe: String?
  let dayDate: String
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

    exerciseName = setRef.exerciseName
    setNumber = setRef.setNumber
    load = "\(setRef.weightKg.map { "\($0)kg" } ?? "-kg")×\(setRef.reps.map(String.init) ?? "-")"
    rpe = setRef.rpe
    dayDate = setRef.dayDate
    self.note = note
    videoURL = message.videoURL.flatMap { $0.absoluteString.isEmpty ? nil : $0 }
  }
}
