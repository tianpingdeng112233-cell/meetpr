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
        .product(name: "Networking", package: "Networking"),
        .product(name: "ChatUI", package: "ChatUI"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
