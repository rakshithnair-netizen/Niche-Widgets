import CoreGraphics

enum WidgetSizing {
    static let minSide: CGFloat = 100
    static let maxSide: CGFloat = 900
    static let pillRatio: CGFloat = 2
    static let tallRatio: CGFloat = 1.5

    static func clamp(_ size: CGSize, shape: WidgetShape) -> CGSize {
        var width = clampSide(size.width)
        var height = clampSide(size.height)
        switch shape {
        case .circle, .square:
            let side = min(width, height)
            return CGSize(width: side, height: side)
        case .widePill:
            if width < height * pillRatio {
                height = max((width / pillRatio).rounded(.down), minSide)
                width = max(width, height * pillRatio)
            }
        case .tallCard:
            if height < width * tallRatio {
                width = max((height / tallRatio).rounded(.down), minSide)
                height = max(height, (width * tallRatio).rounded(.up))
            }
        case .roundedRect, .squircle:
            break
        }
        return CGSize(width: width, height: height)
    }

    private static func clampSide(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return minSide }
        return min(max(value.rounded(), minSide), maxSide)
    }
}
