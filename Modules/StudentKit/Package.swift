// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "StudentKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "StudentKit", targets: ["StudentKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../CatalogKit"),
    .package(path: "../RepositoryContracts"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "StudentKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "CatalogKit", package: "CatalogKit"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "StudentKitTests",
      dependencies: [
        "StudentKit",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
