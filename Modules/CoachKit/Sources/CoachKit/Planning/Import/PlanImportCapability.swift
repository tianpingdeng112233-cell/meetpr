import Foundation

// Gates the plan-import entry point (spec 043 §E1/§G). In-app xlsx import is
// frozen (2026-07-02): the web plan editor is the single import path, so xlsx
// parsing lives in one place instead of two (SheetJS there vs CoreXLSX here —
// every coach-workbook quirk would need fixing twice). The parser plus its
// hardening (`feat/043-import-format-hardening`, pushed) stay dormant, not
// deleted, matching the treatment of other dormant feature work.
//
// This is a real gate, not advisory: when `false`, `ImportEntryButton` renders
// greyed-out and inert, so the flow cannot be reached.
enum PlanImportCapability {
  /// `false` while in-app import is frozen in favour of the web editor. Flip to
  /// `true` to re-enable the full flow; override in previews/tests as needed.
  static var isEnabled: Bool = false
}
