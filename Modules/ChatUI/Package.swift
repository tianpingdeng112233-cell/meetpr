// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "ChatUI",
  // The app ships Chinese only; without this an en-locale device fails to
  // resolve the zh-Hans strings and renders raw keys like "chat.messages".
  defaultLocalization: "zh-Hans",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "ChatUI", targets: ["ChatUI"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../RepositoryContracts"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "ChatUI",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "DesignSystem", package: "DesignSystem"),
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "ChatUITests",
      dependencies: [
        "ChatUI",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
