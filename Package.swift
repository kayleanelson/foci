// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "foci",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "FociCore"),
    .testTarget(name: "FociCoreTests", dependencies: ["FociCore"]),
  ]
)
