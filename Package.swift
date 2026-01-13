// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Waveform",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library( name: "Waveform", targets: ["Waveform"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Waveform", dependencies: []),
        .testTarget(name: "WaveformTests", dependencies: ["Waveform"])
    ]
)
