import Foundation

enum AppVersion {
    private static let fallbackVersion = "dev"
    private static let fallbackBuild = "unbundled"

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? fallbackBuild
    }

    static var dashboardValue: String {
        "v\(shortVersion) (\(buildNumber))"
    }

    static var badgeLabel: String {
        "Build \(buildNumber)"
    }
}
