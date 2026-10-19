// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AdKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "AdKit", targets: ["AdKit"]),
        .library(name: "AdKitAdMob", targets: ["AdKitAdMob"])
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.0.0")
    ],
    targets: [
        .target(name: "AdKit"),
        .target(
            name: "AdKitAdMob",
            dependencies: [
                "AdKit",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads", condition: .when(platforms: [.iOS])),
                .product(name: "GoogleUserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform", condition: .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(name: "AdKitTests", dependencies: ["AdKit"])
    ]
)
