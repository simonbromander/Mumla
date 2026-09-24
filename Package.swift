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
        .executable(name: "mumla-mac", targets: ["MumlaMac"]),
        .executable(name: "mumla-phase0", targets: ["MumlaPhase0CLI"]),
        .executable(name: "mumla-model-probe", targets: ["MumlaModelProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.17.3")
    ],
    targets: [
        .target(name: "MumlaCore"),
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
                "MumlaAudio"
            ]
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
        .testTarget(
            name: "MumlaCoreTests",
            dependencies: ["MumlaCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
