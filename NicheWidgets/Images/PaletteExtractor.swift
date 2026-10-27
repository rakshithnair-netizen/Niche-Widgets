import CoreGraphics
import Foundation
import ImageIO

enum PaletteExtractor {
    static let colorCount = 5
    static let samplePixelSize = 64
    static let iterations = 12

    private struct Point {
        var r: Double
        var g: Double
        var b: Double

        func distance(to other: Point) -> Double {
            let dr = r - other.r
            let dg = g - other.g
            let db = b - other.b
            return dr * dr + dg * dg + db * db
        }
    }

    static func palette(from source: CGImageSource, count: Int = colorCount) -> [String] {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: samplePixelSize
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return [] }
        return palette(from: thumbnail, count: count)
    }

    static func palette(from image: CGImage, count: Int = colorCount) -> [String] {
        let points = samples(from: image)
        guard !points.isEmpty, count > 0 else { return [] }
        let clusters = kMeans(points, k: count)
        var colors = clusters.map { HexColor.string(RGBA(red: $0.r, green: $0.g, blue: $0.b, alpha: 1)) }
        var seen = Set<String>()
        colors = colors.filter { seen.insert($0).inserted }
        var step = 1
        while colors.count < count, let base = clusters.first {
            let factor = 1 - Double(step) * 0.16
            let shade = HexColor.string(RGBA(red: base.r * factor, green: base.g * factor, blue: base.b * factor, alpha: 1))
            let tint = HexColor.string(RGBA(red: base.r + (1 - base.r) * Double(step) * 0.2, green: base.g + (1 - base.g) * Double(step) * 0.2, blue: base.b + (1 - base.b) * Double(step) * 0.2, alpha: 1))
            for candidate in [shade, tint] where colors.count < count && seen.insert(candidate).inserted {
                colors.append(candidate)
            }
            step += 1
            if step > 8 { break }
        }
        return colors
    }

    private static func samples(from image: CGImage) -> [Point] {
        let width = min(image.width, samplePixelSize)
        let height = min(image.height, samplePixelSize)
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return [] }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return [] }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var points: [Point] = []
        points.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            let offset = index * 4
            let alpha = Double(bytes[offset + 3]) / 255
            guard alpha > 0.5 else { continue }
            points.append(Point(
                r: Double(bytes[offset]) / 255 / alpha,
                g: Double(bytes[offset + 1]) / 255 / alpha,
                b: Double(bytes[offset + 2]) / 255 / alpha
            ))
        }
        return points
    }

    private struct Bin {
        var color: Point
        var weight: Double
    }

    private static func histogram(_ points: [Point]) -> [Bin] {
        var sums: [Int: (Point, Double)] = [:]
        for point in points {
            let key = Int(point.r * 15.99) << 8 | Int(point.g * 15.99) << 4 | Int(point.b * 15.99)
            var entry = sums[key] ?? (Point(r: 0, g: 0, b: 0), 0)
            entry.0.r += point.r
            entry.0.g += point.g
            entry.0.b += point.b
            entry.1 += 1
            sums[key] = entry
        }
        return sums.values.map { Bin(color: Point(r: $0.0.r / $0.1, g: $0.0.g / $0.1, b: $0.0.b / $0.1), weight: $0.1) }
            .sorted { $0.weight == $1.weight ? ($0.color.r, $0.color.g, $0.color.b) < ($1.color.r, $1.color.g, $1.color.b) : $0.weight > $1.weight }
    }

    private static func kMeans(_ points: [Point], k: Int) -> [Point] {
        let bins = histogram(points)
        var centers = seeds(bins, k: k)
        var weights = [Double](repeating: 0, count: centers.count)
        for _ in 0..<iterations {
            var sums = [Point](repeating: Point(r: 0, g: 0, b: 0), count: centers.count)
            weights = [Double](repeating: 0, count: centers.count)
            for bin in bins {
                var best = 0
                var bestDistance = Double.infinity
                for (c, center) in centers.enumerated() {
                    let distance = bin.color.distance(to: center)
                    if distance < bestDistance {
                        bestDistance = distance
                        best = c
                    }
                }
                sums[best].r += bin.color.r * bin.weight
                sums[best].g += bin.color.g * bin.weight
                sums[best].b += bin.color.b * bin.weight
                weights[best] += bin.weight
            }
            var moved = 0.0
            for c in centers.indices where weights[c] > 0 {
                let next = Point(r: sums[c].r / weights[c], g: sums[c].g / weights[c], b: sums[c].b / weights[c])
                moved = max(moved, next.distance(to: centers[c]))
                centers[c] = next
            }
            if moved < 1e-6 { break }
        }
        return zip(centers, weights).filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private static func seeds(_ bins: [Bin], k: Int) -> [Point] {
        var seeds: [Point] = []
        for separation in [0.06, 0.02, 0.005, 0] {
            for bin in bins where seeds.count < k {
                if seeds.allSatisfy({ $0.distance(to: bin.color) > separation }) {
                    seeds.append(bin.color)
                }
            }
            if seeds.count == k { break }
        }
        return seeds
    }
}
