// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "Networking", targets: ["Networking"])
  ],
  dependencies: [
    .package(path: "../CoreModels")
  ],
  targets: [
    .target(
      name: "Networking",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels")
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "NetworkingTests",
      dependencies: ["Networking"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
