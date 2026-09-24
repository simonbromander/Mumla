// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mumla",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MumlaCore", targets: ["MumlaCore"]),
        .executable(name: "mumla-phase0", targets: ["MumlaPhase0CLI"])
    ],
    targets: [
        .target(name: "MumlaCore"),
        .executableTarget(
            name: "MumlaPhase0CLI",
            dependencies: ["MumlaCore"]
        ),
        .testTarget(
            name: "MumlaCoreTests",
            dependencies: ["MumlaCore"],
            resources: [.process("Fixtures")]
        )
    ]
)

