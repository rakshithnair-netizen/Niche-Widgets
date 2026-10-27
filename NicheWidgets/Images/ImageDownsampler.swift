import CoreGraphics
import CoreImage
import ImageIO
import Foundation

enum ImageLoadError: Error, Equatable {
    case missing
    case unreadable
}

enum ImageDownsampler {
    private static let blurContext = CIContext(options: [.cacheIntermediates: false])

    static func downsample(contentsOf url: URL, request: ImageRequest) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ImageLoadError.missing }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { throw ImageLoadError.unreadable }
        return try downsample(source: source, request: request)
    }

    static func downsample(source: CGImageSource, request: ImageRequest) throws -> CGImage {
        guard let dimensions = pixelDimensions(of: source) else { throw ImageLoadError.unreadable }
        let maxPixelSize = targetMaxPixelSize(source: dimensions, request: request)
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw ImageLoadError.unreadable }
        guard request.blurRadius > 0 else { return thumbnail }
        return blurred(thumbnail, radius: request.blurRadius) ?? thumbnail
    }

    static func targetMaxPixelSize(source: CGSize, request: ImageRequest) -> Int {
        guard source.width > 0, source.height > 0 else { return max(request.pixelWidth, request.pixelHeight) }
        let scaleX = CGFloat(request.pixelWidth) / source.width
        let scaleY = CGFloat(request.pixelHeight) / source.height
        let factor = (request.fit == .fill ? max(scaleX, scaleY) : min(scaleX, scaleY)) * CGFloat(request.zoom)
        let longest = max(source.width, source.height)
        return Int(min(longest * factor, longest).rounded(.up))
    }

    private static func pixelDimensions(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    private static func blurred(_ image: CGImage, radius: Double) -> CGImage? {
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
        return blurContext.createCGImage(output, from: input.extent)
    }
}
