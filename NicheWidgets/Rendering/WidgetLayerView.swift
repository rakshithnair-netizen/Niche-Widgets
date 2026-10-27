import SwiftUI
import AppKit

final class WidgetHostView: NSView {
    private static let scaleStep: CGFloat = 0.25

    let renderer = WidgetLayerRenderer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.masksToBounds = false
        layer?.isGeometryFlipped = false
        layer?.addSublayer(renderer.rootLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        fitRoot()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        fitRoot()
    }

    func update(_ model: WidgetModel, image: CGImage?, animated: Bool) {
        renderer.apply(model, image: image, animated: animated)
        fitRoot()
    }

    private func fitRoot() {
        let size = renderer.size
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return }
        let fit = min(bounds.width / size.width, bounds.height / size.height)
        let backing = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let quantized = max((backing * fit / Self.scaleStep).rounded(.up) * Self.scaleStep, 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderer.rootLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        renderer.rootLayer.transform = CATransform3DMakeScale(fit, fit, 1)
        CATransaction.commit()
        renderer.setContentsScale(quantized)
    }
}

struct WidgetLayerView: NSViewRepresentable {
    let model: WidgetModel
    var image: CGImage?

    func makeNSView(context: Context) -> WidgetHostView {
        let view = WidgetHostView(frame: .zero)
        view.update(model, image: image, animated: false)
        return view
    }

    func updateNSView(_ view: WidgetHostView, context: Context) {
        view.update(model, image: image, animated: true)
    }
}
