// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "RepositoryContracts",
  platforms: [.iOS(.v17)],
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
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    )
  ]
)
