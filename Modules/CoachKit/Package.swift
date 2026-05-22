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
    .package(path: "../RepositoryContracts"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
  ],
  targets: [
    .target(
      name: "CoachKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CoachKitTests",
      dependencies: [
        "CoachKit",
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
