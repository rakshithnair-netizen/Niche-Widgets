import SwiftUI
import AppKit
import QuartzCore

final class LayerPulseNSView: NSView {
    private static let animationKey = "pulse"

    var minimumOpacity: Float = 0.35
    var duration: CFTimeInterval = 0.9
    var delay: CFTimeInterval = 0
    var isAnimated = true
    var circular = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restart()
    }

    func configure(color: CGColor, cornerRadius: CGFloat?) {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.backgroundColor = color
        layer.cornerCurve = .continuous
        layer.cornerRadius = cornerRadius ?? min(bounds.width, bounds.height) / 2
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        if circular {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.cornerRadius = min(bounds.width, bounds.height) / 2
            CATransaction.commit()
        }
    }

    func restart() {
        guard let layer else { return }
        layer.removeAnimation(forKey: Self.animationKey)
        guard window != nil, isAnimated else {
            layer.opacity = 1
            return
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = minimumOpacity
        animation.duration = duration / 2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.beginTime = CACurrentMediaTime() + delay
        animation.fillMode = .backwards
        layer.add(animation, forKey: Self.animationKey)
    }
}

struct LayerPulse: NSViewRepresentable {
    var color: Color
    var cornerRadius: CGFloat? = nil
    var minimumOpacity: Float = 0.35
    var duration: CFTimeInterval = DS.Motion.typingDuration
    var delay: CFTimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> LayerPulseNSView {
        let view = LayerPulseNSView(frame: .zero)
        apply(to: view)
        return view
    }

    func updateNSView(_ view: LayerPulseNSView, context: Context) {
        let needsRestart = view.isAnimated == reduceMotion || view.minimumOpacity != minimumOpacity || view.duration != duration || view.delay != delay
        apply(to: view)
        if needsRestart { view.restart() }
    }

    private func apply(to view: LayerPulseNSView) {
        view.minimumOpacity = minimumOpacity
        view.duration = duration
        view.delay = delay
        view.isAnimated = !reduceMotion
        view.circular = cornerRadius == nil
        view.configure(color: NSColor(color).cgColor, cornerRadius: cornerRadius)
    }
}
