// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HALeiste",
    platforms: [.macOS(.v14)],
    targets: [
        // Reine Logik ohne Oberfläche (wie logik.js im Plasma-Widget) – wird mit XCTest geprüft
        .target(name: "HALogik"),
        .executableTarget(name: "HALeiste", dependencies: ["HALogik"]),
        .testTarget(name: "HALogikTests", dependencies: ["HALogik"]),
    ],
    swiftLanguageModes: [.v5]
)
