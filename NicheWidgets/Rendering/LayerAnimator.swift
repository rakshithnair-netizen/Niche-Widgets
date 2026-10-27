import AppKit
import QuartzCore

@MainActor
struct LayerAnimator {
    let isEnabled: Bool
    var motion: DS.Motion = .smooth

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func set(_ layer: CALayer, _ keyPath: String, _ value: Any?) {
        if isEnabled {
            let from = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
            let animation = makeAnimation(keyPath)
            animation.fromValue = from
            animation.toValue = value
            layer.add(animation, forKey: keyPath)
        }
        layer.setValue(value, forKeyPath: keyPath)
    }

    func fadeIn(_ layer: CALayer, to opacity: Float) {
        guard isEnabled else {
            layer.opacity = opacity
            return
        }
        layer.opacity = 0
        set(layer, "opacity", opacity)
    }

    private func makeAnimation(_ keyPath: String) -> CABasicAnimation {
        if Self.reduceMotion {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.duration = DS.Motion.reducedDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            return animation
        }
        let animation = CASpringAnimation(perceptualDuration: motion.response, bounce: 1 - motion.dampingFraction)
        animation.keyPath = keyPath
        animation.duration = animation.settlingDuration
        return animation
    }
}
