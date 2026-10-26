import Foundation

/// Server-authoritative history for one accepted binding (spec 095 AMEND).
public struct BindFirstRun: Codable, Hashable, Sendable {
  public let bindingPlanCount: Int
  public let hasSettledDay: Bool
  public let firstPlan: FirstPlan?

  public init(bindingPlanCount: Int, hasSettledDay: Bool, firstPlan: FirstPlan? = nil) {
    self.bindingPlanCount = bindingPlanCount
    self.hasSettledDay = hasSettledDay
    self.firstPlan = firstPlan
  }

  public struct FirstPlan: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let publishedAt: Date
    public let planWeeks: Int
    public let dayCount: Int
    public let hasSettledDay: Bool

    public init(id: UUID, publishedAt: Date, planWeeks: Int, dayCount: Int, hasSettledDay: Bool) {
      self.id = id
      self.publishedAt = publishedAt
      self.planWeeks = planWeeks
      self.dayCount = dayCount
      self.hasSettledDay = hasSettledDay
    }
  }
}
