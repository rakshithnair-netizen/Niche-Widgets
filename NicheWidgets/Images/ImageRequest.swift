import CoreGraphics

struct ImageRequest: Hashable, Sendable {
    let reference: String
    let pixelWidth: Int
    let pixelHeight: Int
    let fit: WidgetImageFit
    let zoom: Double
    let blurRadius: Double

    var cacheKey: String {
        "\(reference)|\(pixelWidth)x\(pixelHeight)|\(fit.rawValue)|\(zoom)|\(blurRadius)"
    }
}

extension WidgetModel {
    func imageRequest(scale: CGFloat) -> ImageRequest? {
        guard background.kind == .image, let reference = image.reference, !reference.isEmpty else { return nil }
        let size = resolvedSize
        let pixelScale = max(scale, 1)
        let zoomStep = 4.0
        let zoom = (min(max(image.zoom, 1), 4) * zoomStep).rounded(.up) / zoomStep
        return ImageRequest(
            reference: reference,
            pixelWidth: Int((size.width * pixelScale).rounded()),
            pixelHeight: Int((size.height * pixelScale).rounded()),
            fit: image.fit,
            zoom: zoom,
            blurRadius: (max(glass.blurRadius, 0) * Double(pixelScale)).rounded()
        )
    }
}
