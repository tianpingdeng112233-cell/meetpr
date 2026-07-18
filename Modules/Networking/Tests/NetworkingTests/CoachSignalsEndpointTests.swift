import Foundation
import Testing

@testable import Networking

@Test func coachDiscoveryEndpointsDecodeBackendShapesAndUseOpenFilter() async throws {
  let requests = CoachDiscoveryRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await requests.record(request)
    let path = request.url?.path() ?? ""
    if path == "/coach/signals" {
      return APIResponse(data: Data(SelfTestJSON.signals.utf8), statusCode: 200)
    }
    return APIResponse(data: Data(SelfTestJSON.digest.utf8), statusCode: 200)
  }

  let signals = try await client.coachSignals(accessToken: "token")
  let digest = try await client.coachDailyDigest(accessToken: "token")

  #expect(signals.signals.map(\.signalType) == ["missed_training", "weight_failed", "pr_congrats"])
  #expect(signals.signals[1].payload.failedCount == 2)
  #expect(signals.signals[2].payload.e1rm == 102.5)
  #expect(digest.gymDay == "2026-07-17")
  #expect(digest.counts.sessionCompleted == 3)
  #expect(digest.counts.weightFailed == 1)
  #expect(digest.body == "昨天 · 3 练完 · 1 缺练 · 1 被压 · 1 破 PR")

  #expect(
    await requests.paths() == [
      "GET /coach/signals?status=open",
      "GET /coach/daily-digest",
    ])
}

private actor CoachDiscoveryRequestLog {
  private var values: [String] = []

  func record(_ request: URLRequest) {
    let method = request.httpMethod ?? ""
    var path = request.url?.path() ?? ""
    if let query = request.url?.query(), !query.isEmpty {
      path += "?\(query)"
    }
    values.append("\(method) \(path)")
  }

  func paths() -> [String] {
    values
  }
}

private enum SelfTestJSON {
  static let signals = #"""
    {
      "signals": [
        {
          "id": "00000000-0000-4000-8000-000000000001",
          "student_id": "00000000-0000-4000-8000-000000000101",
          "student_name": "王晨曦",
          "signal_type": "missed_training",
          "severity": "red",
          "status": "open",
          "reason": "连续 3 个训练日无打卡",
          "payload": { "missed_dates": ["2026-07-15"], "consecutive_count": 3 },
          "opened_at": "2026-07-18T08:00:00Z",
          "expires_at": "2026-07-25T08:00:00Z"
        },
        {
          "id": "00000000-0000-4000-8000-000000000002",
          "student_id": "00000000-0000-4000-8000-000000000102",
          "student_name": "张以恒",
          "signal_type": "weight_failed",
          "severity": "yellow",
          "status": "open",
          "reason": "硬拉被压",
          "payload": { "gym_day": "2026-07-18", "failed_count": 2 },
          "opened_at": "2026-07-18T07:00:00Z",
          "expires_at": null
        },
        {
          "id": "00000000-0000-4000-8000-000000000003",
          "student_id": "00000000-0000-4000-8000-000000000103",
          "student_name": "李嘉宁",
          "signal_type": "pr_congrats",
          "severity": "green",
          "status": "open",
          "reason": "卧推刷新 PR",
          "payload": { "family": "bench", "e1rm": 102.5 },
          "opened_at": "2026-07-18T06:00:00Z",
          "expires_at": "2026-07-25T06:00:00Z"
        }
      ]
    }
    """#

  static let digest = #"""
    {
      "gym_day": "2026-07-17",
      "counts": {
        "session_completed": 3,
        "session_partial": 0,
        "missed_training": 1,
        "weight_failed": 1,
        "pr_e1rm": 1
      },
      "body": "昨天 · 3 练完 · 1 缺练 · 1 被压 · 1 破 PR"
    }
    """#
}
