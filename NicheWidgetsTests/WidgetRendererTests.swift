import AppKit
import Darwin
import ImageIO
import QuartzCore
import Testing
@testable import Niche_Widgets

@MainActor
struct WidgetRendererTests {
    private func allLayers(_ layer: CALayer) -> [CALayer] {
        [layer] + (layer.mask.map(allLayers) ?? []) + (layer.sublayers ?? []).flatMap(allLayers)
    }

    private func textLayers(_ renderer: WidgetLayerRenderer) -> [CATextLayer] {
        allLayers(renderer.rootLayer).compactMap { $0 as? CATextLayer }
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> RGBA? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: 4)
        return RGBA(red: Double(bytes[0]) / 255, green: Double(bytes[1]) / 255, blue: Double(bytes[2]) / 255, alpha: Double(bytes[3]) / 255)
    }

    private static func physicalFootprint() -> Int64 {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? Int64(usage.ri_phys_footprint) : 0
    }

    private func testImage() -> CGImage? {
        guard let full = ProceduralArtwork.orbs.render() else { return nil }
        let request = ImageRequest(reference: "test", pixelWidth: 338, pixelHeight: 338, fit: .fill, zoom: 1, blurRadius: 0)
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, full, nil)
        CGImageDestinationFinalize(destination)
        guard let source = CGImageSourceCreateWithData(data, nil) else { return nil }
        return try? ImageDownsampler.downsample(source: source, request: request)
    }

    @Test func snapshotHasExactPixelSize() throws {
        var model = WidgetModel()
        model.size = WidgetSize(preset: .medium)
        let image = try #require(WidgetSnapshot.render(model, image: nil, scale: 2))
        #expect(image.width == 676)
        #expect(image.height == 316)
        let exact = try #require(WidgetSnapshot.render(model, image: nil, pixelSize: CGSize(width: 101, height: 47), scale: 1))
        #expect(exact.width == 101)
        #expect(exact.height == 47)
    }

    @Test func snapshotIsUprightAndMasked() throws {
        var model = WidgetModel()
        model.shape = .circle
        model.size = WidgetSize(preset: .small)
        model.borderWidth = 0
        model.glass.rimHighlightOpacity = 0
        model.background = WidgetBackground(kind: .linearGradient, color: "#FF0000", gradient: WidgetGradient(colors: ["#FF0000", "#0000FF"], angle: 180))
        let image = try #require(WidgetSnapshot.render(model, image: nil, scale: 1))
        let top = try #require(pixel(image, x: 79, y: 8))
        let bottom = try #require(pixel(image, x: 79, y: 150))
        let corner = try #require(pixel(image, x: 2, y: 2))
        #expect(top.red > top.blue)
        #expect(bottom.blue > bottom.red)
        #expect(corner.alpha < 0.05)
    }

    @Test func smallEditsReuseTheLayerTree() {
        let renderer = WidgetLayerRenderer()
        var model = SampleWidgets.make()[0]
        renderer.apply(model, image: nil, animated: false)
        let before = allLayers(renderer.rootLayer).map(ObjectIdentifier.init)
        let textBefore = textLayers(renderer).map(ObjectIdentifier.init)

        model.borderOpacity = 0.6
        model.glass.tintOpacity = 0.3
        model.textLayers[1].content = "Tuesday"
        renderer.apply(model, image: nil, animated: true)
        #expect(allLayers(renderer.rootLayer).map(ObjectIdentifier.init) == before)
        #expect(textLayers(renderer).map(ObjectIdentifier.init) == textBefore)

        model.textLayers.append(WidgetTextLayer(content: "New"))
        renderer.apply(model, image: nil, animated: true)
        let textAfterAdd = textLayers(renderer).map(ObjectIdentifier.init)
        #expect(textAfterAdd.count == 3)
        #expect(Array(textAfterAdd.prefix(2)) == textBefore)

        model.textLayers.remove(at: 0)
        renderer.apply(model, image: nil, animated: true)
        #expect(textLayers(renderer).map(ObjectIdentifier.init) == Array(textAfterAdd.suffix(2)))
    }

    @Test func rendererIsReleased() {
        weak var weakRenderer: WidgetLayerRenderer?
        weak var weakRoot: CALayer?
        autoreleasepool {
            let renderer = WidgetLayerRenderer()
            renderer.apply(SampleWidgets.make()[1], image: testImage(), animated: false)
            weakRenderer = renderer
            weakRoot = renderer.rootLayer
        }
        CATransaction.flush()
        #expect(weakRenderer == nil)
        #expect(weakRoot == nil)
    }

    @Test func downsamplingMatchesWidgetPixelSize() throws {
        let image = try #require(testImage())
        #expect(image.width == 338)
        #expect(image.height == 338)
    }

    @Test func hundredWidgetsKeepMemoryFlat() throws {
        let image = try #require(testImage())
        let samples = SampleWidgets.make()
        let models = (0..<100).map { samples[$0 % samples.count] }
        var footprints: [Int64] = []
        for _ in 0..<10 {
            autoreleasepool {
                let renderers = models.map { model in
                    let renderer = WidgetLayerRenderer()
                    renderer.apply(model, image: image, animated: false)
                    return renderer
                }
                for (renderer, model) in zip(renderers, models) {
                    var edited = model
                    edited.glass.tintOpacity += 0.1
                    renderer.apply(edited, image: image, animated: true)
                    _ = WidgetSnapshot.render(model, image: image, scale: 1)
                }
                CATransaction.flush()
            }
            footprints.append(Self.physicalFootprint())
        }
        let baseline = footprints[1]
        let peak = footprints.dropFirst().max() ?? baseline
        let growth = peak - baseline
        #expect(growth < 12 * 1024 * 1024, "Footprints: \(footprints.map { $0 / 1024 / 1024 }) MB")
    }
}
