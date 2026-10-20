// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tatakikun",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "TatakikunCore", targets: ["TatakikunCore"]),
        .executable(name: "Tatakikun", targets: ["Tatakikun"]),
        .executable(name: "tatakikun-cli", targets: ["tatakikun-cli"]),
        .executable(name: "tatakikun-dictgen", targets: ["tatakikun-dictgen"]),
    ],
    targets: [
        .target(name: "TatakikunCore"),
        .executableTarget(name: "tatakikun-dictgen", dependencies: ["TatakikunCore"]),
        .executableTarget(name: "tatakikun-cli", dependencies: ["TatakikunCore"]),
        .executableTarget(name: "Tatakikun", dependencies: ["TatakikunCore"]),
        .testTarget(name: "TatakikunCoreTests", dependencies: ["TatakikunCore"]),
    ]
)
