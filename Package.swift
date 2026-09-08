// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexQuotaBadge",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CodexQuotaBadge", targets: ["CodexQuotaBadge"]),
        .executable(name: "CodexQuotaBadgeTestRunner", targets: ["CodexQuotaBadgeTestRunner"])
    ],
    targets: [
        .target(name: "CodexQuotaBadgeCore"),
        .executableTarget(name: "CodexQuotaBadge", dependencies: ["CodexQuotaBadgeCore"]),
        .executableTarget(
            name: "CodexQuotaBadgeTestRunner",
            dependencies: ["CodexQuotaBadgeCore"],
            path: "Tests/CodexQuotaBadgeTestRunner"
        )
    ]
)
