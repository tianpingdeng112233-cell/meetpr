import Foundation

// Gates the plan-import entry point (spec 043 §G deployment note). Import depends
// on the backend PR that widens `plan_weeks`/`week_number` and persists
// `coach_note`; until that ships, a pre-043 backend rejects `plan_weeks != {1,4}`
// and silently drops the cue. So the entry stays hidden by default and is flipped
// on only once the backend capability is known live.
//
// This is a real gate, not advisory: when `false`, `ImportEntryButton` renders
// nothing, so the feature cannot be reached.
enum PlanImportCapability {
  /// `true` once the backend that supports arbitrary weeks + `coach_note` is
  /// deployed. Kept `false` until then; override in previews/tests as needed.
  static var isEnabled: Bool = false
}
