import SwiftUI
import CoreGraphics

enum WidgetShapePath {
    static let superellipseExponent: CGFloat = 5
    static let superellipseSegments = 240

    static func cornerRadius(for shape: WidgetShape, size: CGSize, requested: Double) -> CGFloat {
        let limit = min(size.width, size.height) / 2
        switch shape {
        case .circle, .widePill: return limit
        case .squircle: return 0
        case .square, .tallCard, .roundedRect: return min(max(CGFloat(requested), 0), limit)
        }
    }

    static func path(for shape: WidgetShape, in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGPath(rect: .zero, transform: nil) }
        switch shape {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .widePill:
            return Capsule(style: .continuous).path(in: rect).cgPath
        case .squircle:
            return superellipse(in: rect)
        case .square, .tallCard, .roundedRect:
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect).cgPath
        }
    }

    static func path(for shape: WidgetShape, size: CGSize, cornerRadius: CGFloat, inset: CGFloat) -> CGPath {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        return path(for: shape, in: rect, cornerRadius: max(cornerRadius - inset, 0))
    }

    static func superellipse(in rect: CGRect, exponent: CGFloat = superellipseExponent, segments: Int = superellipseSegments) -> CGPath {
        let path = CGMutablePath()
        let a = rect.width / 2
        let b = rect.height / 2
        let power = 2 / exponent
        for index in 0..<segments {
            let t = CGFloat(index) / CGFloat(segments) * 2 * .pi
            let c = cos(t)
            let s = sin(t)
            let point = CGPoint(
                x: rect.midX + a * copysign(pow(abs(c), power), c),
                y: rect.midY + b * copysign(pow(abs(s), power), s)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct WidgetOutline: Shape {
    let shape: WidgetShape
    let widgetSize: CGSize
    let cornerRadius: Double

    init(_ model: WidgetModel) {
        shape = model.shape
        widgetSize = model.resolvedSize
        cornerRadius = model.cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        guard widgetSize.width > 0 else { return Path() }
        let scale = rect.width / widgetSize.width
        let radius = WidgetShapePath.cornerRadius(for: shape, size: widgetSize, requested: cornerRadius) * scale
        return Path(WidgetShapePath.path(for: shape, in: rect, cornerRadius: radius))
    }
}
