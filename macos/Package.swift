// swift-tools-version: 6.0
import PackageDescription

// Nur die Logik (wie logik.js im Plasma-Widget) – mit XCTest geprüft.
// Die App selbst und die Widgets baut das Xcode-Projekt (project.yml, erzeugt mit XcodeGen).
let package = Package(
    name: "HALeiste",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HALogik", targets: ["HALogik"])],
    targets: [
        .target(name: "HALogik"),
        .testTarget(name: "HALogikTests", dependencies: ["HALogik"]),
    ],
    swiftLanguageModes: [.v5]
)
