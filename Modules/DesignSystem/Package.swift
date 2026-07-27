// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "DesignSystem",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "DesignSystem", targets: ["DesignSystem"])
  ],
  dependencies: [
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
  ],
  targets: [
    .target(
      name: "DesignSystem",
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "DesignSystemTests",
      dependencies: [
        "DesignSystem",
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
