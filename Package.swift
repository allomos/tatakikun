// swift-tools-version:5.9
import PackageDescription

// The engine, its tests and tatakikun-cli build everywhere; the macOS input method and the
// dictionary generator (CoreFoundation's tokenizer, ICU transforms) only on a Mac.
var products: [Product] = [
    .library(name: "TatakikunCore", targets: ["TatakikunCore"]),
    // The engine as one shared library with a C interface (ttk_*), for apps on other platforms
    // (the Android keyboard, Windows, Linux).
    .library(name: "TatakikunEngine", type: .dynamic, targets: ["TatakikunBridge"]),
    .executable(name: "tatakikun-cli", targets: ["tatakikun-cli"]),
]
var targets: [Target] = [
    .target(name: "TatakikunCore"),
    .target(name: "TatakikunBridge", dependencies: ["TatakikunCore"]),
    .executableTarget(name: "tatakikun-cli", dependencies: ["TatakikunCore"]),
    .testTarget(name: "TatakikunCoreTests", dependencies: ["TatakikunCore"]),
]
#if os(macOS)
products += [
    .executable(name: "Tatakikun", targets: ["Tatakikun"]),
    .executable(name: "tatakikun-dictgen", targets: ["tatakikun-dictgen"]),
]
targets += [
    .executableTarget(name: "tatakikun-dictgen", dependencies: ["TatakikunCore"]),
    .executableTarget(name: "Tatakikun", dependencies: ["TatakikunCore"]),
]
#endif

let package = Package(
    name: "Tatakikun",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: products,
    targets: targets
)
