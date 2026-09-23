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
    .library(name: "DevilProbe", targets: ["DevilProbe"]),
  ],
  // Upstream's own package, not one of the community wrappers. It depends on
  // nothing itself. Dual licensed BSD-3-Clause or GPL-2.0, taken as BSD.
  dependencies: [
    .package(url: "https://github.com/facebook/zstd", from: "1.5.7"),
  ],
  targets: [
    .target(
      name: "DevilKit",
      path: "Sources/DevilKit"
    ),
    // The probe decode, kept out of `DevilKit` so that package stays free of
    // Foundation and of dependencies. It still builds for the host, so the
    // whole chain from bytes to temperatures is testable without a phone,
    // which matters more here than anywhere else in the app.
    .target(
      name: "DevilProbe",
      dependencies: [
        "DevilKit",
        .product(name: "libzstd", package: "zstd"),
      ],
      path: "Sources/DevilProbe"
    ),
    .testTarget(
      name: "DevilKitTests",
      dependencies: ["DevilKit"],
      path: "Tests/DevilKitTests"
    ),
    .testTarget(
      name: "DevilProbeTests",
      dependencies: ["DevilProbe"],
      path: "Tests/DevilProbeTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
