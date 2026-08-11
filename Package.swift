// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clockin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Clockin", targets: ["Clockin"])
    ],
    targets: [
        .executableTarget(
            name: "Clockin",
            path: "Sources/Clockin",
            resources: [.process("Assets")]
        )
    ]
)
