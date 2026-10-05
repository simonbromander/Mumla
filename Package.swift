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
        .library(name: "MumlaAudio", targets: ["MumlaAudio"]),
        .library(name: "MumlaUI", targets: ["MumlaUI"]),
        .executable(name: "mumla-mac", targets: ["MumlaMac"]),
        .executable(name: "mumla-phase0", targets: ["MumlaPhase0CLI"]),
        .executable(name: "mumla-model-probe", targets: ["MumlaModelProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.17.3"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.0")
    ],
    targets: [
        .target(name: "MumlaCore"),
        .target(name: "MumlaUI", dependencies: ["MumlaCore"], resources: [.process("Resources")]),
        .target(
            name: "MumlaAudio",
            dependencies: [
                "MumlaCore",
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .executableTarget(
            name: "MumlaMac",
            dependencies: [
                "MumlaCore",
                "MumlaAudio",
                "MumlaUI",
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS]))
            ],
            swiftSettings: [.define("MUMLA_DIRECT_UPDATES", .when(platforms: [.macOS]))]
        ),
        .executableTarget(
            name: "MumlaPhase0CLI",
            dependencies: ["MumlaCore"]
        ),
        .executableTarget(
            name: "MumlaModelProbe",
            dependencies: [
                "MumlaCore",
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .testTarget(name: "MumlaMacTests", dependencies: ["MumlaMac", "MumlaCore", "MumlaAudio", "MumlaUI"]),
        .testTarget(
            name: "MumlaCoreTests",
            dependencies: ["MumlaCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
