// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Boo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Boo",
            path: "Sources/Boo",
            // @main lives in BooApp.swift; without this SwiftPM also
            // synthesises an entry point into the first file it compiles.
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
