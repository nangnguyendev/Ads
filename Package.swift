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
        .library(name: "AdKitAdMob", targets: ["AdKitAdMob"]),
        .library(name: "AdKitAdMobMediation", targets: ["AdKitAdMobMediation"])
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.0.0"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-applovin.git", from: "13.6.400"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-unity.git", from: "4.21.0"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-liftoffmonetize.git", from: "7.7.800"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-meta.git", from: "6.22.0"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-mintegral.git", from: "8.1.700"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-inmobi.git", from: "11.5.0"),
        .package(url: "https://github.com/googleads/googleads-mobile-ios-mediation-moloco.git", from: "4.11.100")
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
        .target(
            name: "AdKitAdMobMediation",
            dependencies: [
                "AdKit",
                "AdKitAdMob",
                .product(name: "AppLovinAdapterTarget", package: "googleads-mobile-ios-mediation-applovin", condition: .when(platforms: [.iOS])),
                .product(name: "UnityAdapterTarget", package: "googleads-mobile-ios-mediation-unity", condition: .when(platforms: [.iOS])),
                .product(name: "LiftoffMonetizeAdapterTarget", package: "googleads-mobile-ios-mediation-liftoffmonetize", condition: .when(platforms: [.iOS])),
                .product(name: "MetaAdapterTarget", package: "googleads-mobile-ios-mediation-meta", condition: .when(platforms: [.iOS])),
                .product(name: "MintegralAdapterTarget", package: "googleads-mobile-ios-mediation-mintegral", condition: .when(platforms: [.iOS])),
                .product(name: "InMobiAdapterTarget", package: "googleads-mobile-ios-mediation-inmobi", condition: .when(platforms: [.iOS])),
                .product(name: "MolocoAdapterTarget", package: "googleads-mobile-ios-mediation-moloco", condition: .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(name: "AdKitTests", dependencies: ["AdKit"])
    ]
)
