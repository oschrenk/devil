// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "DevilKit",
  // .macOS is what lets `swift test` run on the host. Without it SwiftPM has
  // no platform it can build a test bundle for, and every check would need a
  // simulator and xcodebuild. .iOS is the platform the app target links.
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "DevilKit", targets: ["DevilKit"]),
  ],
  targets: [
    .target(
      name: "DevilKit",
      path: "Sources/DevilKit"
    ),
    .testTarget(
      name: "DevilKitTests",
      dependencies: ["DevilKit"],
      path: "Tests/DevilKitTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
