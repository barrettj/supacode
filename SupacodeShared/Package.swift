// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SupacodeShared",
  platforms: [.macOS(.v26), .iOS(.v26)],
  products: [
    .library(name: "SupacodeShared", targets: ["SupacodeShared"]),
  ],
  targets: [
    .target(name: "SupacodeShared"),
    .testTarget(name: "SupacodeSharedTests", dependencies: ["SupacodeShared"]),
  ]
)
