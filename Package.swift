// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "DropConvert",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "DropConvert", targets: ["DropConvert"])],
  targets: [
    .target(
      name: "ConvertKit",
      swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    ),
    .executableTarget(
      name: "DropConvert",
      dependencies: ["ConvertKit"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(name: "ConvertKitTests", dependencies: ["ConvertKit"]),
  ]
)
