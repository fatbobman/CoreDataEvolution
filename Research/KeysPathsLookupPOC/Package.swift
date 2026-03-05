// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "KeysPathsLookupPOC",
  products: [
    .library(
      name: "KeysPathsLookupPOC",
      targets: ["KeysPathsLookupPOC"]
    )
  ],
  targets: [
    .target(
      name: "KeysPathsLookupPOC"
    ),
    .testTarget(
      name: "KeysPathsLookupPOCTests",
      dependencies: ["KeysPathsLookupPOC"]
    ),
  ]
)
