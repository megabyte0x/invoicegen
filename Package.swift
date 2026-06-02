// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "InvoiceGen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "InvoiceCore", targets: ["InvoiceCore"]),
        .executable(name: "InvoiceGen", targets: ["InvoiceGenApp"])
    ],
    targets: [
        .target(name: "InvoiceCore"),
        .executableTarget(
            name: "InvoiceGenApp",
            dependencies: ["InvoiceCore"],
            path: "Sources/InvoiceGenApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "InvoiceCoreTests",
            dependencies: ["InvoiceCore"]
        ),
        .testTarget(
            name: "InvoiceGenAppTests",
            dependencies: ["InvoiceCore", "InvoiceGenApp"]
        )
    ]
)
