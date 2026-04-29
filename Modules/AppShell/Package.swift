// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "AppShell",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "AppShell", targets: ["AppShell"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
    .package(path: "../CoachKit"),
    .package(path: "../StudentKit"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
  ],
  targets: [
    .target(
      name: "AppShell",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "CoachKit", package: "CoachKit"),
        .product(name: "StudentKit", package: "StudentKit"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "AppShellTests",
      dependencies: [
        "AppShell",
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
