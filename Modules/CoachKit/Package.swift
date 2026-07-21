// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "CoachKit",
  // The app ships Chinese only; without this an en-locale device fails to
  // resolve the zh-Hans strings and renders raw keys like "chat.messages".
  defaultLocalization: "zh-Hans",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CoachKit", targets: ["CoachKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
    .package(path: "../RepositoryContracts"),
    .package(path: "../Analytics"),
    .package(path: "../ChatUI"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    // Read-only XLSX parsing for coach plan import (spec 043). Apache-2.0,
    // pure Swift. Pinned exact — the importer depends on its cell-addressing.
    .package(url: "https://github.com/CoreOffice/CoreXLSX", exact: "0.14.2"),
  ],
  targets: [
    .target(
      name: "CoachKit",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "Analytics", package: "Analytics"),
        .product(name: "ChatUI", package: "ChatUI"),
        .product(name: "CoreXLSX", package: "CoreXLSX"),
      ],
      resources: [.process("Resources")],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CoachKitTests",
      dependencies: [
        "CoachKit",
        .product(name: "Networking", package: "Networking"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "ChatUI", package: "ChatUI"),
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
