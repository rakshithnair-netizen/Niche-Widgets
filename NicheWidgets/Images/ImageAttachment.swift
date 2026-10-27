import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageAttachment: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let thumbnail: CGImage
    let palette: [String]

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum ImageAttachmentLoader {
    static let thumbnailPixelSize = 160
    static let maxAttachments = 4

    static func isImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    @concurrent
    static func load(url: URL) async throws -> ImageAttachment {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageLoadError.unreadable
        }
        return try make(source: source, name: url.lastPathComponent)
    }

    @concurrent
    static func load(data: Data, name: String) async throws -> ImageAttachment {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageLoadError.unreadable
        }
        return try make(source: source, name: name)
    }

    static func make(source: CGImageSource, name: String) throws -> ImageAttachment {
        try Task.checkCancellation()
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixelSize
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw ImageLoadError.unreadable }
        let palette = PaletteExtractor.palette(from: thumbnail)
        guard !palette.isEmpty else { throw ImageLoadError.unreadable }
        return ImageAttachment(name: name, thumbnail: thumbnail, palette: palette)
    }

    static func combinedPalette(_ attachments: [ImageAttachment], count: Int = PaletteExtractor.colorCount) -> [String] {
        var seen = Set<String>()
        var colors: [String] = []
        let depth = attachments.map(\.palette.count).max() ?? 0
        for index in 0..<depth {
            for attachment in attachments where index < attachment.palette.count {
                let color = attachment.palette[index]
                guard colors.count < count, seen.insert(color).inserted else { continue }
                colors.append(color)
            }
        }
        return colors
    }
}
