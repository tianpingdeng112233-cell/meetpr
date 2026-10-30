import Networking
import Observation

@MainActor
@Observable
final class MinimumVersionGateModel {
  private(set) var minimumBuild: Int?
  private var hasStarted = false
  private let api: APIClient
  private let currentBuild: Int?

  init(api: APIClient = .shared, currentBuild: Int? = BuildConfig.buildNumber()) {
    self.api = api
    self.currentBuild = currentBuild
  }

  func check() async {
    guard !hasStarted else { return }
    hasStarted = true
    minimumBuild = await api.requiredAppUpdate(currentBuild: currentBuild)
  }
}
