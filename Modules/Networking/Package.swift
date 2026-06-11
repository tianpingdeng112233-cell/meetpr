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
        .product(name: "CoreModels", package: "CoreModels")
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "NetworkingTests",
      dependencies: [
        "Networking",
        // Test-only: asserts the machine-code → typed-error mapping against
        // wire envelopes (spec 031/032). The Networking library itself stays
        // contracts-free.
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
