// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "StudentKit",
  defaultLocalization: "zh-Hans",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "StudentKit", targets: ["StudentKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../RepositoryContracts"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
    .package(path: "../Analytics"),
    .package(path: "../ChatUI"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
  ],
  targets: [
    .target(
      name: "StudentKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "Analytics", package: "Analytics"),
        .product(name: "ChatUI", package: "ChatUI"),
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "StudentKitTests",
      dependencies: [
        "StudentKit",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "ChatUI", package: "ChatUI"),
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
