import Foundation

public enum Equipment: String, Codable, Hashable, Sendable, CaseIterable {
  case barbell = "barbell"
  case dumbbell = "dumbbell"
  case machine = "machine"
  case bodyweight = "bodyweight"
  case cable = "cable"
  case band = "band"
  case kettlebell = "kettlebell"
  case specialtyBar = "specialty_bar"
  case other = "other"
}
