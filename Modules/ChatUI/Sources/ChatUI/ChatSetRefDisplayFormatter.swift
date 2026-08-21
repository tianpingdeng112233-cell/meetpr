import CoreModels
import Foundation

public enum ChatSetRefDisplayFormatter {
  public static func firstLine(
    for setRef: SetRefV1,
    locale: Locale = .current
  ) -> String {
    firstLine(for: setRef, copy: .localized(locale: locale))
  }

  static func firstLine(for setRef: SetRefV1, copy: Copy) -> String {
    let prefix = setRef.source == .logged ? copy.loggedTag : copy.plannedTag
    let setDescription = copy.setPosition(setRef.setNumber, setRef.setTotal)
    let plannedMarker = setRef.source == .planned ? copy.plannedMarker : ""
    let weight = setRef.weightKg.map { "\($0)kg" } ?? "-kg"
    let reps: String
    if let lowerBound = setRef.reps, let upperBound = setRef.repsMax {
      reps = "\(lowerBound)-\(upperBound)"
    } else {
      reps = setRef.reps.map(String.init) ?? "-"
    }
    let rpe = setRef.rpe.map { " @RPE\($0)" } ?? ""
    return
      "\(prefix) \(setRef.exerciseName) \(setDescription)\(plannedMarker) "
      + "\(weight)×\(reps)\(rpe) (\(setRef.dayDate))"
  }
}

extension ChatSetRefDisplayFormatter {
  struct Copy {
    let loggedTag: String
    let plannedTag: String
    let plannedMarker: String
    let setPosition: (_ setNumber: Int, _ total: Int?) -> String

    static func localized(locale: Locale) -> Self {
      Self(
        loggedTag: ChatStrings.setReferenceLoggedTag(locale: locale),
        plannedTag: ChatStrings.setReferencePlannedTag(locale: locale),
        plannedMarker: ChatStrings.setReferencePlannedMarker(locale: locale),
        setPosition: { setNumber, total in
          if let total {
            return ChatStrings.setPosition(setNumber, total: total, locale: locale)
          }
          return ChatStrings.setPosition(setNumber, locale: locale)
        }
      )
    }
  }
}
