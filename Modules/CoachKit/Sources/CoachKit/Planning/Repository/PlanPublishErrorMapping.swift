import Foundation
import Networking

/// Publish真-gate machine codes → banner copy (spec 033 §10). The planning
/// UI currently ends at Step 7 (Step 8 publish is spec 008); the publish
/// flow consumes this mapping when it lands. Publish failures never clear
/// the draft (DraftStore behavior unchanged).
public enum PlanPublishErrorMapping {
  /// nil = not a publish gate code; callers fall back to the generic
  /// failure copy.
  public static func bannerMessage(for error: any Error) -> String? {
    switch BackendErrorEnvelope.machineCode(from: error) {
    case "EVALUATION_IN_PROGRESS":
      // 403: active evaluation period and the plan is not a 1-week
      // adaptation week.
      return "评估期内只能发布 1 周适应周计划。先完成评估,或改发适应周。"
    case "PLAN_DAYS_EXCEED_WEEKS":
      // 422: backend backstop — the editor keeps days within planWeeks, so
      // reaching this means a UI bug.
      return "计划里有超出周数范围的训练日,请检查后重试。"
    default:
      return nil
    }
  }
}
