import Foundation

enum CoreModelStrings {
  static let loggedSetTag = localized("coreModels.setReference.loggedTag")
  static let plannedSetTag = localized("coreModels.setReference.plannedTag")
  static let plannedMarker = localized("coreModels.setReference.plannedMarker")

  static func setNumber(_ setNumber: Int) -> String {
    let formattedSetNumber = String(setNumber)
    return String(
      localized: "coreModels.setReference.set \(formattedSetNumber)",
      bundle: .module
    )
  }

  static func setNumber(_ setNumber: Int, total: Int) -> String {
    let formattedSetNumber = String(setNumber)
    let formattedTotal = String(total)
    return String(
      localized: "coreModels.setReference.set \(formattedSetNumber) of \(formattedTotal)",
      bundle: .module
    )
  }

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
