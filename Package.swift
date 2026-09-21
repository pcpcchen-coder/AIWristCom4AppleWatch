// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AIWristCore", platforms: [.macOS(.v14)],
    products: [.library(name: "AIWristCore", targets: ["AIWristCore"])],
    targets: [.target(name: "AIWristCore", path: "Shared"),
              .testTarget(name: "AIWristCoreTests", dependencies: ["AIWristCore"], path: "tests/CoreTests")])
