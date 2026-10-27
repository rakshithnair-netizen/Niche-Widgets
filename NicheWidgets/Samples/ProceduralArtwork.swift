import CoreGraphics
import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum ProceduralArtwork: String, CaseIterable, Sendable {
    case aurora, dunes, strata, orbs, grain

    var reference: String { "procedural/\(rawValue)" }

    var pixelSize: (width: Int, height: Int) {
        switch self {
        case .dunes: (900, 1350)
        case .strata: (1400, 700)
        default: (1024, 1024)
        }
    }

    @concurrent
    static func generateMissing(in disk: ImageDiskCache) async throws {
        for artwork in allCases where !disk.contains(artwork.reference) {
            try Task.checkCancellation()
            guard let image = artwork.render() else { continue }
            try disk.store(image, for: artwork.reference)
        }
    }

    func render() -> CGImage? {
        let (width, height) = pixelSize
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let size = CGSize(width: width, height: height)
        var rng = SeededGenerator(seed: UInt64(rawValue.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt32($1.value) }))
        switch self {
        case .aurora: drawAurora(context, size, &rng)
        case .dunes: drawDunes(context, size, &rng)
        case .strata: drawStrata(context, size, &rng)
        case .orbs: drawOrbs(context, size, &rng)
        case .grain: drawGrain(context, size, &rng)
        }
        addNoise(context, amplitude: noiseAmplitude, rng: &rng)
        return context.makeImage()
    }

    private var noiseAmplitude: Int {
        switch self {
        case .aurora: 6
        case .dunes: 5
        case .strata: 12
        case .orbs: 4
        case .grain: 22
        }
    }

    private func color(_ hex: String, _ alpha: Double = 1) -> CGColor {
        HexColor.cgColor(hex, opacity: alpha)
    }

    private func linear(_ context: CGContext, _ colors: [String], from start: CGPoint, to end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: nil, colors: colors.map { color($0) } as CFArray, locations: nil) else { return }
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func radial(_ context: CGContext, center: CGPoint, radius: CGFloat, inner: CGColor, outer: CGColor) {
        guard let gradient = CGGradient(colorsSpace: nil, colors: [inner, outer] as CFArray, locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    private func drawAurora(_ context: CGContext, _ size: CGSize, _ rng: inout SeededGenerator) {
        linear(context, ["#0B1020", "#141B33"], from: .zero, to: CGPoint(x: 0, y: size.height))
        context.setBlendMode(.screen)
        let palette = ["#2FD1B5", "#7A5CFF", "#FF6FA8", "#B8F06A", "#3A8DFF", "#2FD1B5"]
        for hex in palette {
            let center = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height * 0.8, using: &rng))
            let radius = CGFloat.random(in: size.width * 0.3...size.width * 0.6, using: &rng)
            radial(context, center: center, radius: radius, inner: color(hex, 0.75), outer: color(hex, 0))
        }
        context.setBlendMode(.normal)
    }

    private func drawDunes(_ context: CGContext, _ size: CGSize, _ rng: inout SeededGenerator) {
        linear(context, ["#F7D3AE", "#EBA27A", "#D9775A"], from: .zero, to: CGPoint(x: 0, y: size.height * 0.6))
        radial(context, center: CGPoint(x: size.width * 0.68, y: size.height * 0.26), radius: size.width * 0.16, inner: color("#FFF3DC", 0.95), outer: color("#FFF3DC", 0))
        let bands = ["#C9744F", "#A85A45", "#86453E", "#653437", "#4A2732", "#331C29"]
        for (index, hex) in bands.enumerated() {
            let base = size.height * (0.42 + CGFloat(index) * 0.1)
            let amplitude = CGFloat.random(in: 18...46, using: &rng)
            let frequency = CGFloat.random(in: 1.2...2.6, using: &rng)
            let phase = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size.height))
            for step in 0...120 {
                let x = size.width * CGFloat(step) / 120
                let t = x / size.width * 2 * .pi
                let y = base + amplitude * sin(t * frequency + phase) + amplitude * 0.35 * sin(t * frequency * 2.7 + phase * 1.3)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color(hex))
            context.fillPath()
        }
    }

    private func drawStrata(_ context: CGContext, _ size: CGSize, _ rng: inout SeededGenerator) {
        let palette = ["#2E2A27", "#4A4038", "#7A6A58", "#A89580", "#D8C8B0", "#5E6B60", "#8C9A8B", "#3B3530"]
        context.setFillColor(color(palette[0]))
        context.fill(CGRect(origin: .zero, size: size))
        var top: CGFloat = 0
        var index = 0
        while top < size.height {
            let thickness = CGFloat.random(in: size.height * 0.04...size.height * 0.12, using: &rng)
            let wobble = CGFloat.random(in: 4...16, using: &rng)
            let frequency = CGFloat.random(in: 2...6, using: &rng)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size.height))
            for step in 0...140 {
                let x = size.width * CGFloat(step) / 140
                path.addLine(to: CGPoint(x: x, y: top + wobble * sin(x / size.width * frequency * .pi + CGFloat(index))))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color(palette[index % palette.count]))
            context.fillPath()
            top += thickness
            index += 1
        }
    }

    private func drawOrbs(_ context: CGContext, _ size: CGSize, _ rng: inout SeededGenerator) {
        linear(context, ["#0B0F1A", "#1C2340"], from: .zero, to: CGPoint(x: size.width, y: size.height))
        let palette = ["#FFB86B", "#FF6B6B", "#6BCBFF", "#C38BFF", "#7CF2C8"]
        for index in 0..<14 {
            let hex = palette[index % palette.count]
            let radius = CGFloat.random(in: size.width * 0.06...size.width * 0.24, using: &rng)
            let center = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng))
            radial(context, center: center, radius: radius, inner: color(hex, 0.9), outer: color(hex, 0.05))
            let highlight = CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35)
            radial(context, center: highlight, radius: radius * 0.45, inner: color("#FFFFFF", 0.35), outer: color("#FFFFFF", 0))
        }
    }

    private func drawGrain(_ context: CGContext, _ size: CGSize, _ rng: inout SeededGenerator) {
        linear(context, ["#3D2B56", "#E2725B", "#F2C14E"], from: .zero, to: CGPoint(x: size.width, y: size.height))
        context.setBlendMode(.softLight)
        for _ in 0..<5 {
            let x = CGFloat.random(in: 0...size.width, using: &rng)
            let streak = CGMutablePath()
            streak.move(to: CGPoint(x: x, y: 0))
            streak.addLine(to: CGPoint(x: x + size.width * 0.12, y: 0))
            streak.addLine(to: CGPoint(x: x - size.width * 0.3, y: size.height))
            streak.addLine(to: CGPoint(x: x - size.width * 0.42, y: size.height))
            streak.closeSubpath()
            context.addPath(streak)
            context.setFillColor(color("#FFFFFF", 0.35))
            context.fillPath()
        }
        context.setBlendMode(.normal)
    }

    private func addNoise(_ context: CGContext, amplitude: Int, rng: inout SeededGenerator) {
        guard amplitude > 0, let data = context.data else { return }
        let width = context.width
        let height = context.height
        let bytesPerRow = context.bytesPerRow
        let pixels = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        for row in 0..<height {
            let rowStart = row * bytesPerRow
            for column in 0..<width {
                let offset = rowStart + column * 4
                let delta = Int(rng.next() % UInt64(amplitude * 2 + 1)) - amplitude
                for channel in 0..<3 {
                    let value = Int(pixels[offset + channel]) + delta
                    pixels[offset + channel] = UInt8(clamping: value)
                }
                pixels[offset + 3] = 255
            }
        }
    }
}
