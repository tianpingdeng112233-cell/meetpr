// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "Analytics",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "Analytics", targets: ["Analytics"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),
  ],
  targets: [
    .target(
      name: "Analytics",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "AnalyticsTests",
      dependencies: ["Analytics"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
