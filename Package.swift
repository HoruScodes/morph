// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Morph",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "Morph", targets: ["Morph"])],
  targets: [
    .target(
      name: "ConvertKit",
      swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    ),
    .executableTarget(
      name: "Morph",
      dependencies: ["ConvertKit"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(name: "ConvertKitTests", dependencies: ["ConvertKit"]),
  ]
)
