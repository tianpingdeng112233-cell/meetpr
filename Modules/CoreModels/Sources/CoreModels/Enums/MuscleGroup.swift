import Foundation

public enum MuscleGroup: String, Codable, Hashable, Sendable, CaseIterable {
  case chest = "chest"
  case shoulder = "shoulder"
  case back = "back"
  case biceps = "biceps"
  case triceps = "triceps"
  case forearm = "forearm"
  case core = "core"
  case quad = "quad"
  case hamstring = "hamstring"
  case glute = "glute"
  case hip = "hip"
  case hipFlexor = "hip_flexor"
  case adductor = "adductor"
  case calf = "calf"
  case tibialis = "tibialis"
  case trap = "trap"
  case mobility = "mobility"
  case cardio = "cardio"
  case grip = "grip"
}
