// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SafeKeylogger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SafeKeylogger", targets: ["SafeKeylogger"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "SafeKeylogger",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "SafeKeylogger",
            exclude: ["Info.plist"]
        )
    ]
)
