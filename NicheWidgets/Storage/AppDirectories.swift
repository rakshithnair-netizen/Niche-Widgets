import Foundation

enum AppDirectories {
    static let root = URL.applicationSupportDirectory.appending(path: "Niche-Widgets", directoryHint: .isDirectory)
    static let widgets = root.appending(path: "Widgets", directoryHint: .isDirectory)
    static let imageCache = root.appending(path: "ImageCache", directoryHint: .isDirectory)
    static let samplesMarker = root.appending(path: ".samples-seeded", directoryHint: .notDirectory)

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
