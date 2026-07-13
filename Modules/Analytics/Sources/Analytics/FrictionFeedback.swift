import Foundation
import Observation
import SwiftUI

public struct FrictionFeedbackPrompt: Identifiable, Sendable {
  public let id: UUID
  public let flow: AnalyticsFlow
  public let fromScreen: AnalyticsScreen
  public let trigger: FrictionTrigger
}

@MainActor
@Observable
public final class FrictionFeedbackController {
  public static let shared = FrictionFeedbackController()

  public private(set) var pendingPrompt: FrictionFeedbackPrompt?

  private let defaults: UserDefaults
  private let maxPromptsPerFlow: Int
  private let cooldown: TimeInterval
  private let now: @MainActor () -> Date
  private let track: @MainActor (AnalyticsEvent, [String: AnalyticsValue]) -> Void
  private let prepare:
    @MainActor (AnalyticsFlow, AnalyticsScreen, FrictionTrigger) async -> FrictionFeedbackContext?
  private let submit:
    @MainActor (UUID, AnalyticsFlow, AnalyticsScreen, FrictionTrigger, String) -> Void
  private var shownThisSession = false
  private var isPreparing = false

  init(
    defaults: UserDefaults = .standard,
    maxPromptsPerFlow: Int = 3,
    cooldown: TimeInterval = 7 * 24 * 60 * 60,
    now: @escaping @MainActor () -> Date = { Date() },
    track: @escaping @MainActor (AnalyticsEvent, [String: AnalyticsValue]) -> Void = {
      Analytics.shared.track($0, props: $1)
    },
    prepare:
      @escaping @MainActor (
        AnalyticsFlow, AnalyticsScreen, FrictionTrigger
      ) async -> FrictionFeedbackContext? = {
        await Analytics.shared.prepareFrictionFeedback(
          flow: $0, fromScreen: $1, trigger: $2)
      },
    submit:
      @escaping @MainActor (
        UUID, AnalyticsFlow, AnalyticsScreen, FrictionTrigger, String
      ) -> Void = {
        Analytics.shared.submitFrictionText(
          eventID: $0, flow: $1, fromScreen: $2, trigger: $3, text: $4)
      }
  ) {
    self.defaults = defaults
    self.maxPromptsPerFlow = maxPromptsPerFlow
    self.cooldown = cooldown
    self.now = now
    self.track = track
    self.prepare = prepare
    self.submit = submit
  }

  public func recordReEdit(
    flow: AnalyticsFlow,
    field: AnalyticsField,
    count: Int,
    fromScreen: AnalyticsScreen
  ) {
    guard count >= 2 else { return }
    track(
      .fieldReEdit,
      [
        "flow": .enumCase(flow),
        "field": .enumCase(field),
        "count": .int(count),
      ])
    consider(flow: flow, fromScreen: fromScreen, trigger: .reEdit)
  }

  public func recordFlowCancel(flow: AnalyticsFlow, fromScreen: AnalyticsScreen) {
    track(
      .flowCancel,
      [
        "flow": .enumCase(flow),
        "from_screen": .enumCase(fromScreen),
      ])
    consider(flow: flow, fromScreen: fromScreen, trigger: .flowCancel)
  }

  public func send(text: String) {
    guard let prompt = pendingPrompt else { return }
    submit(prompt.id, prompt.flow, prompt.fromScreen, prompt.trigger, text)
    pendingPrompt = nil
  }

  public func skip() {
    defaults.set(now(), forKey: Keys.cooldownStartedAt)
    pendingPrompt = nil
  }

  func beginSession() {
    shownThisSession = false
    isPreparing = false
    pendingPrompt = nil
  }

  private func consider(
    flow: AnalyticsFlow,
    fromScreen: AnalyticsScreen,
    trigger: FrictionTrigger
  ) {
    guard !shownThisSession, !isPreparing, pendingPrompt == nil else { return }
    if let skippedAt = defaults.object(forKey: Keys.cooldownStartedAt) as? Date,
      now().timeIntervalSince(skippedAt) < cooldown
    {
      return
    }
    let countKey = Keys.flowCount(flow)
    guard defaults.integer(forKey: countKey) < maxPromptsPerFlow else { return }
    isPreparing = true
    Task {
      let context = await prepare(flow, fromScreen, trigger)
      isPreparing = false
      guard let context else { return }
      shownThisSession = true
      defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
      pendingPrompt = FrictionFeedbackPrompt(
        id: context.eventID,
        flow: flow,
        fromScreen: fromScreen,
        trigger: trigger
      )
    }
  }

  private enum Keys {
    static let cooldownStartedAt = "meetpr.analytics.friction.cooldown_started_at"

    static func flowCount(_ flow: AnalyticsFlow) -> String {
      "meetpr.analytics.friction.flow.\(flow.rawValue).count"
    }
  }
}

extension View {
  public func analyticsFrictionFeedbackPrompt() -> some View {
    modifier(FrictionFeedbackPromptModifier())
  }
}

private struct FrictionFeedbackPromptModifier: ViewModifier {
  @State private var controller = FrictionFeedbackController.shared

  func body(content: Content) -> some View {
    content.sheet(item: promptBinding) { _ in
      FrictionFeedbackSheet(controller: controller)
        .presentationDetents([.height(240)])
    }
  }

  private var promptBinding: Binding<FrictionFeedbackPrompt?> {
    Binding(
      get: { controller.pendingPrompt },
      set: { if $0 == nil { controller.skip() } }
    )
  }
}

private struct FrictionFeedbackSheet: View {
  let controller: FrictionFeedbackController
  @State private var text = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("卡住了?一句话告诉我们")
        .font(.headline)
      TextField("哪里让你不顺手?", text: $text, axis: .vertical)
        .lineLimit(1...3)
        .textFieldStyle(.roundedBorder)
      HStack {
        Button("跳过") { controller.skip() }
        Spacer()
        Button("发送") { controller.send(text: text) }
          .buttonStyle(.borderedProminent)
          .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding()
  }
}
