// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "shadow_action_skill",
    platforms: [
        .macOS("14.2")
    ],
    products: [
        .library(name: "shadow-action-skill", targets: ["shadow_action_skill"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", branch: "main"),
        .package(url: "https://github.com/phoneixtaperlabs/shadow_whisper.git", branch: "main")
    ],
    targets: [
        .target(
            name: "shadow_action_skill",
            dependencies: [
                .product(name: "shadow_whisper", package: "shadow_whisper"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it collects user
                // data, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
