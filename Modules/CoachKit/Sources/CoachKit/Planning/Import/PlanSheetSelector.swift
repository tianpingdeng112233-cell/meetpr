import Foundation

// Picks which worksheet holds the plan to import (spec 043 hardening). Replaces the
// name-based ignore-list, which was tuned to 吕子豪's workbook and skipped 邓天平's
// current "2026" sheet. Judgement is structural (does the sheet parse into week
// blocks?) plus recency (whose dates are newest = the current cycle).

enum PlanSheetSelector {
  /// Returns the grid of the most-recent sheet that parses into ≥1 week block with
  /// training content, or nil if no candidate has one. A date-only year skeleton or
  /// notes sheet (week headers but no exercises) is rejected even when its dates are
  /// newest — otherwise the builder would drop everything and review would be empty.
  static func selectPlanSheet(from candidates: [(name: String, grid: CellGrid)]) -> CellGrid? {
    var best: (grid: CellGrid, recency: Double)?
    for candidate in candidates {
      let offset = PlanSheetGeometry.detectDayOffset(in: candidate.grid)
      let contentBlocks = PlanSheetGeometry.weekBlocks(in: candidate.grid, offset: offset)
        .filter { !$0.contentRows.isEmpty }
      guard !contentBlocks.isEmpty else { continue }
      let recency = contentBlocks.flatMap(\.dateSerials).compactMap { $0 }.max() ?? 0
      if let current = best, recency <= current.recency { continue }
      best = (candidate.grid, recency)
    }
    return best?.grid
  }
}
