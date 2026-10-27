import CoreGraphics
import QuartzCore

@MainActor
enum WidgetSnapshot {
    static func render(_ model: WidgetModel, image: CGImage?, scale: CGFloat) -> CGImage? {
        let size = model.resolvedSize
        let pixelSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        return render(model, image: image, pixelSize: pixelSize, scale: scale)
    }

    static func render(_ model: WidgetModel, image: CGImage?, pixelSize: CGSize, scale: CGFloat) -> CGImage? {
        let size = model.resolvedSize
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        guard width > 0, height > 0, size.width > 0, size.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
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
        let renderer = WidgetLayerRenderer()
        renderer.setContentsScale(max(scale, 1))
        renderer.apply(model, image: image, animated: false)
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(width) / size.width, y: -CGFloat(height) / size.height)
        renderer.rootLayer.render(in: context)
        return context.makeImage()
    }
}
