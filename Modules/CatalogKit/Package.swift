// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "CatalogKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CatalogKit", targets: ["CatalogKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels")
  ],
  targets: [
    .target(
      name: "CatalogKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels")
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CatalogKitTests",
      dependencies: ["CatalogKit"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
