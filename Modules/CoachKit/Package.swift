// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "CoachKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CoachKit", targets: ["CoachKit"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../CatalogKit"),
    .package(path: "../Networking"),
    .package(path: "../DesignSystem"),
    .package(path: "../RepositoryContracts"),
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
        .product(name: "CatalogKit", package: "CatalogKit"),
        .product(name: "Networking", package: "Networking"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "CoreXLSX", package: "CoreXLSX"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "CoachKitTests",
      dependencies: [
        "CoachKit",
        .product(name: "Networking", package: "Networking"),
        .product(name: "RepositoryContracts", package: "RepositoryContracts"),
        .product(name: "ViewInspector", package: "ViewInspector"),
      ],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
