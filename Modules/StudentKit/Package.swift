// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "StudentKit",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "StudentKit", targets: ["StudentKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "StudentKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "StudentKitTests",
      dependencies: ["StudentKit"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
