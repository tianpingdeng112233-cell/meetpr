// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "CoreModels",
  defaultLocalization: "zh-Hans",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CoreModels", targets: ["CoreModels"])
  ],
  targets: [
    .target(
      name: "CoreModels",
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CoreModelsTests",
      dependencies: ["CoreModels"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
