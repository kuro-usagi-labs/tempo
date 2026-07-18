// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TempoDomain",
    products: [.library(name: "TempoDomain", targets: ["TempoDomain"])],
    targets: [.target(name: "TempoDomain", path: "Sources")]
)
