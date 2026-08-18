// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "RepositoryContracts",
  defaultLocalization: "zh-Hans",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "RepositoryContracts", targets: ["RepositoryContracts"])
  ],
  dependencies: [
    .package(path: "../CoreModels")
  ],
  targets: [
    .target(
      name: "RepositoryContracts",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels")
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "RepositoryContractsTests",
      dependencies: ["RepositoryContracts"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
