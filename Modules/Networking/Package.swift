// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "Networking", targets: ["Networking"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../RepositoryContracts"),
  ],
  targets: [
    .target(
      name: "Networking",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "NetworkingTests",
      dependencies: [
        "Networking",
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
