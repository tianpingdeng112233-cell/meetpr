import Observation

@Observable @MainActor
final class ProfileNavigation {
  var destination: ProfileMenuDestination?
}
