import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageMemoryCache: @unchecked Sendable {
    private let cache = NSCache<NSString, CGImage>()

    init(byteLimit: Int) {
        cache.totalCostLimit = byteLimit
    }

    func image(for key: String) -> CGImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: CGImage, for key: String) {
        cache.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

struct ImageDiskCache: Sendable {
    let directory: URL

    static func hash(_ reference: String) -> String {
        SHA256.hash(data: Data(reference.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func url(for reference: String) -> URL {
        directory.appending(path: Self.hash(reference) + ".png", directoryHint: .notDirectory)
    }

    func contains(_ reference: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: reference).path)
    }

    func store(_ image: CGImage, for reference: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ImageLoadError.unreadable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImageLoadError.unreadable }
        try (data as Data).write(to: url(for: reference), options: .atomic)
    }
}
