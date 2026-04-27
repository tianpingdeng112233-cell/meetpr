// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "CoachKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CoachKit", targets: ["CoachKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "CoachKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CoachKitTests",
      dependencies: ["CoachKit"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
