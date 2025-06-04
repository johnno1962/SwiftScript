// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

//
// *** This repo isn't actually used as a Swift Package, run ./start.sh instead. ***
//

import PackageDescription

let package = Package(
    name: "swiftscript",
    platforms: [.macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "swiftscript",
            targets: ["swiftscript"]),
    ],
    dependencies: [
      /*PACKAGES*/
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "swiftscript"),
    ]
)
