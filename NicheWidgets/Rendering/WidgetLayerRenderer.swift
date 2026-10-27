import AppKit
import QuartzCore

@MainActor
final class WidgetLayerRenderer {
    static let textInset: CGFloat = 14
    static let rimLineWidth: CGFloat = 1.5

    let rootLayer = CALayer()
    private let shadowLayer = CALayer()
    private let bodyLayer = CALayer()
    private let bodyMask = CAShapeLayer()
    private let solidLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let imageLayer = CALayer()
    private let scrimLayer = CAGradientLayer()
    private let tintLayer = CALayer()
    private let textContainer = CALayer()
    private let rimLayer = CAGradientLayer()
    private let rimMask = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private var textLayers: [UUID: CATextLayer] = [:]
    private var model: WidgetModel?
    private var image: CGImage?
    private(set) var size: CGSize = .zero
    private(set) var contentsScale: CGFloat = 2

    init() {
        build()
    }

    func apply(_ next: WidgetModel, image nextImage: CGImage?, animated: Bool) {
        let previous = model
        let animator = LayerAnimator(isEnabled: animated && previous != nil)
        let nextSize = next.resolvedSize
        let geometryChanged = previous.map {
            $0.resolvedSize != nextSize || $0.shape != next.shape || $0.cornerRadius != next.cornerRadius
        } ?? true
        let imageChanged = nextImage !== image

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if geometryChanged {
            applyGeometry(next, size: nextSize, animator)
        }
        if geometryChanged || previous?.borderWidth != next.borderWidth || previous?.borderOpacity != next.borderOpacity {
            applyBorder(next, size: nextSize, animator)
        }
        if previous?.background != next.background {
            applyBackground(next.background, animator)
        }
        if geometryChanged || previous?.image != next.image || previous?.background.kind != next.background.kind || imageChanged {
            applyImage(next, image: nextImage, size: nextSize, imageChanged: imageChanged, animator)
        }
        if previous?.overlay != next.overlay {
            applyOverlay(next.overlay, animator)
        }
        if previous?.glass != next.glass {
            applyGlass(next.glass, animator)
        }
        if geometryChanged || previous?.textLayers != next.textLayers {
            applyText(next.textLayers, previous: previous?.textLayers ?? [], size: nextSize, geometryChanged: geometryChanged, animator)
        }
        model = next
        image = nextImage
        size = nextSize
        CATransaction.commit()
    }

    func setContentsScale(_ scale: CGFloat) {
        guard scale > 0, scale != contentsScale else { return }
        contentsScale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        propagateScale(rootLayer)
        CATransaction.commit()
    }

    private func propagateScale(_ layer: CALayer) {
        layer.contentsScale = contentsScale
        if let mask = layer.mask {
            propagateScale(mask)
        }
        layer.sublayers?.forEach(propagateScale)
    }

    private func build() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        rootLayer.isGeometryFlipped = true
        rootLayer.masksToBounds = false
        shadowLayer.shadowColor = CGColor(gray: 0, alpha: 1)
        bodyMask.fillColor = CGColor(gray: 0, alpha: 1)
        bodyLayer.mask = bodyMask
        imageLayer.masksToBounds = false
        imageLayer.opacity = 0
        gradientLayer.opacity = 0
        rimMask.fillColor = nil
        rimMask.strokeColor = CGColor(gray: 0, alpha: 1)
        rimMask.lineWidth = Self.rimLineWidth
        rimLayer.mask = rimMask
        rimLayer.colors = [
            CGColor(gray: 1, alpha: 1),
            CGColor(gray: 1, alpha: 0.25),
            CGColor(gray: 1, alpha: 0.05),
            CGColor(gray: 1, alpha: 0.3)
        ]
        rimLayer.locations = [0, 0.35, 0.7, 1]
        rimLayer.startPoint = CGPoint(x: 0.5, y: 0)
        rimLayer.endPoint = CGPoint(x: 0.5, y: 1)
        borderLayer.fillColor = nil
        [bodyLayer, solidLayer, gradientLayer, imageLayer, scrimLayer, tintLayer, textContainer, rimLayer, borderLayer, shadowLayer].forEach {
            $0.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        rootLayer.addSublayer(shadowLayer)
        rootLayer.addSublayer(bodyLayer)
        bodyLayer.addSublayer(solidLayer)
        bodyLayer.addSublayer(gradientLayer)
        bodyLayer.addSublayer(imageLayer)
        bodyLayer.addSublayer(scrimLayer)
        bodyLayer.addSublayer(tintLayer)
        bodyLayer.addSublayer(textContainer)
        bodyLayer.addSublayer(rimLayer)
        bodyLayer.addSublayer(borderLayer)
        propagateScale(rootLayer)
    }

    private var fullBleedLayers: [CALayer] {
        [shadowLayer, bodyLayer, bodyMask, solidLayer, gradientLayer, imageLayer, scrimLayer, tintLayer, textContainer, rimLayer, rimMask, borderLayer]
    }

    private func applyGeometry(_ model: WidgetModel, size: CGSize, _ animator: LayerAnimator) {
        let bounds = NSValue(rect: CGRect(origin: .zero, size: size))
        let center = NSValue(point: CGPoint(x: size.width / 2, y: size.height / 2))
        animator.set(rootLayer, "bounds", bounds)
        for layer in fullBleedLayers {
            animator.set(layer, "bounds", bounds)
            animator.set(layer, "position", center)
        }
        let radius = WidgetShapePath.cornerRadius(for: model.shape, size: size, requested: model.cornerRadius)
        let outline = WidgetShapePath.path(for: model.shape, size: size, cornerRadius: radius, inset: 0)
        let rim = WidgetShapePath.path(for: model.shape, size: size, cornerRadius: radius, inset: Self.rimLineWidth / 2)
        animator.set(bodyMask, "path", outline)
        animator.set(shadowLayer, "shadowPath", outline)
        animator.set(rimMask, "path", rim)
    }

    private func applyBorder(_ model: WidgetModel, size: CGSize, _ animator: LayerAnimator) {
        let width = CGFloat(max(model.borderWidth, 0))
        let radius = WidgetShapePath.cornerRadius(for: model.shape, size: size, requested: model.cornerRadius)
        let path = WidgetShapePath.path(for: model.shape, size: size, cornerRadius: radius, inset: width / 2)
        animator.set(borderLayer, "path", path)
        animator.set(borderLayer, "lineWidth", width)
        animator.set(borderLayer, "strokeColor", CGColor(gray: 1, alpha: width > 0 ? min(max(model.borderOpacity, 0), 1) : 0))
    }

    private func applyBackground(_ background: WidgetBackground, _ animator: LayerAnimator) {
        animator.set(solidLayer, "backgroundColor", HexColor.cgColor(background.color))
        let colors = background.gradient.colors.isEmpty ? [background.color] : background.gradient.colors
        let gradientColors = colors.count == 1 ? [colors[0], colors[0]] : colors
        animator.set(gradientLayer, "colors", gradientColors.map { HexColor.cgColor($0) })
        let points = Self.gradientPoints(angle: background.gradient.angle)
        animator.set(gradientLayer, "startPoint", NSValue(point: points.start))
        animator.set(gradientLayer, "endPoint", NSValue(point: points.end))
        animator.set(gradientLayer, "opacity", Float(background.kind == .linearGradient ? 1 : 0))
    }

    private func applyImage(_ model: WidgetModel, image: CGImage?, size: CGSize, imageChanged: Bool, _ animator: LayerAnimator) {
        let settings = model.image
        let visible: Float = model.background.kind == .image && image != nil ? 1 : 0
        imageLayer.contentsGravity = settings.fit == .fill ? .resizeAspectFill : .resizeAspect
        if imageChanged {
            imageLayer.contents = image
            if visible > 0 {
                LayerAnimator(isEnabled: true, motion: .smooth).fadeIn(imageLayer, to: visible)
            } else {
                imageLayer.opacity = visible
            }
        } else {
            animator.set(imageLayer, "opacity", visible)
        }
        let zoom = CGFloat(min(max(settings.zoom, 0.25), 4))
        var transform = CATransform3DMakeTranslation(CGFloat(settings.offsetX) * size.width, CGFloat(settings.offsetY) * size.height, 0)
        transform = CATransform3DRotate(transform, CGFloat(settings.rotation) * .pi / 180, 0, 0, 1)
        transform = CATransform3DScale(transform, zoom, zoom, 1)
        animator.set(imageLayer, "transform", NSValue(caTransform3D: transform))
    }

    private func applyOverlay(_ overlay: WidgetOverlay, _ animator: LayerAnimator) {
        let opacity = min(max(overlay.opacity, 0), 1)
        let extent = CGFloat(min(max(overlay.extent, 0.05), 1))
        animator.set(scrimLayer, "colors", [HexColor.cgColor(overlay.color, opacity: opacity), HexColor.cgColor(overlay.color, opacity: 0)])
        let start: CGPoint
        let end: CGPoint
        switch overlay.direction {
        case .bottom:
            start = CGPoint(x: 0.5, y: 1)
            end = CGPoint(x: 0.5, y: 1 - extent)
        case .top:
            start = CGPoint(x: 0.5, y: 0)
            end = CGPoint(x: 0.5, y: extent)
        case .leading:
            start = CGPoint(x: 0, y: 0.5)
            end = CGPoint(x: extent, y: 0.5)
        case .trailing:
            start = CGPoint(x: 1, y: 0.5)
            end = CGPoint(x: 1 - extent, y: 0.5)
        }
        scrimLayer.startPoint = start
        scrimLayer.endPoint = end
    }

    private func applyGlass(_ glass: WidgetGlass, _ animator: LayerAnimator) {
        animator.set(tintLayer, "backgroundColor", HexColor.cgColor(glass.tintColor, opacity: glass.tintOpacity))
        animator.set(rimLayer, "opacity", Float(min(max(glass.rimHighlightOpacity, 0), 1)))
        animator.set(shadowLayer, "shadowOpacity", Float(min(max(glass.shadow.opacity, 0), 1)))
        animator.set(shadowLayer, "shadowRadius", CGFloat(max(glass.shadow.radius, 0)))
        animator.set(shadowLayer, "shadowOffset", NSValue(size: CGSize(width: glass.shadow.offsetX, height: glass.shadow.offsetY)))
    }

    private func applyText(_ layers: [WidgetTextLayer], previous: [WidgetTextLayer], size: CGSize, geometryChanged: Bool, _ animator: LayerAnimator) {
        let previousByID = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let nextIDs = Set(layers.map(\.id))
        for (id, layer) in textLayers where !nextIDs.contains(id) {
            layer.removeFromSuperlayer()
            textLayers[id] = nil
        }
        for (index, text) in layers.enumerated() {
            if let layer = textLayers[text.id] {
                if geometryChanged || previousByID[text.id] != text {
                    layoutText(layer, text, size: size, animator)
                }
                if textContainer.sublayers?.firstIndex(of: layer) != index {
                    textContainer.insertSublayer(layer, at: UInt32(index))
                }
            } else {
                let layer = makeTextLayer()
                textLayers[text.id] = layer
                textContainer.insertSublayer(layer, at: UInt32(min(index, textContainer.sublayers?.count ?? 0)))
                layoutText(layer, text, size: size, LayerAnimator(isEnabled: false))
                if animator.isEnabled {
                    animator.fadeIn(layer, to: layer.opacity)
                }
            }
        }
    }

    private func makeTextLayer() -> CATextLayer {
        let layer = CATextLayer()
        layer.isWrapped = true
        layer.truncationMode = .end
        layer.contentsScale = contentsScale
        return layer
    }

    private func layoutText(_ layer: CATextLayer, _ text: WidgetTextLayer, size: CGSize, _ animator: LayerAnimator) {
        let font = WidgetFonts.font(name: text.fontName, size: text.size, weight: text.weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = text.alignment.textAlignment
        paragraph.lineBreakMode = .byWordWrapping
        let color = NSColor(cgColor: HexColor.cgColor(text.color)) ?? .white
        let attributed = NSAttributedString(string: text.content, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        let maxWidth = max(size.width - Self.textInset * 2, 1)
        let measured = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let frameSize = CGSize(width: min(ceil(measured.width) + 2, maxWidth), height: min(ceil(measured.height), size.height))
        layer.string = attributed
        layer.alignmentMode = text.alignment.alignmentMode
        layer.anchorPoint = CGPoint(x: text.alignment.anchorX, y: 0.5)
        animator.set(layer, "bounds", NSValue(rect: CGRect(origin: .zero, size: frameSize)))
        animator.set(layer, "position", NSValue(point: CGPoint(x: CGFloat(text.x) * size.width, y: CGFloat(text.y) * size.height)))
        animator.set(layer, "opacity", Float(min(max(text.opacity, 0), 1)))
    }

    static func gradientPoints(angle: Double) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * .pi / 180
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        return (CGPoint(x: 0.5 - dx, y: 0.5 - dy), CGPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}
