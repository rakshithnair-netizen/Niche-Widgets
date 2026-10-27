import CoreGraphics
import Foundation

final class ImagePipeline: Sendable {
    static let memoryByteLimit = 96 * 1024 * 1024
    static let shared = ImagePipeline(disk: ImageDiskCache(directory: AppDirectories.imageCache), memory: ImageMemoryCache(byteLimit: memoryByteLimit))

    let disk: ImageDiskCache
    let memory: ImageMemoryCache

    init(disk: ImageDiskCache, memory: ImageMemoryCache) {
        self.disk = disk
        self.memory = memory
    }

    func cachedImage(for request: ImageRequest) -> CGImage? {
        memory.image(for: request.cacheKey)
    }

    @concurrent
    func image(for request: ImageRequest) async throws -> CGImage {
        if let cached = memory.image(for: request.cacheKey) { return cached }
        try Task.checkCancellation()
        let image = try ImageDownsampler.downsample(contentsOf: disk.url(for: request.reference), request: request)
        memory.insert(image, for: request.cacheKey)
        try Task.checkCancellation()
        return image
    }
}
