import SwiftUI

enum PlaceholderWidgetKind: CaseIterable {
    case square, widePill, tallCard, circle, roundedRect

    var title: String {
        switch self {
        case .square: "Square"
        case .widePill: "Wide Pill"
        case .tallCard: "Tall Card"
        case .circle: "Circle"
        case .roundedRect: "Rounded Rect"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .square, .circle: 1
        case .widePill: 2.4
        case .tallCard: 0.62
        case .roundedRect: 1.35
        }
    }

    var contentAlignment: Alignment {
        switch self {
        case .circle: .center
        case .widePill: .leading
        default: .bottomLeading
        }
    }
}

struct PlaceholderWidgetShape: InsettableShape {
    let kind: PlaceholderWidgetKind
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: insetAmount, dy: insetAmount)
        switch kind {
        case .circle:
            return Circle().path(in: inset)
        case .widePill:
            return Capsule(style: .continuous).path(in: inset)
        default:
            return RoundedRectangle(cornerRadius: max(DS.Radius.lg - insetAmount, 0), style: .continuous).path(in: inset)
        }
    }

    func inset(by amount: CGFloat) -> PlaceholderWidgetShape {
        PlaceholderWidgetShape(kind: kind, insetAmount: insetAmount + amount)
    }
}

struct PlaceholderArtwork: View {
    let seed: Int

    var body: some View {
        let colors = DS.Palette.artwork[abs(seed) % DS.Palette.artwork.count]
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            EllipticalGradient(
                colors: [DS.Palette.artworkHighlight, .clear],
                center: UnitPoint(x: 0.22, y: 0.18),
                startRadiusFraction: 0,
                endRadiusFraction: 0.75
            )
        }
    }
}

struct PlaceholderWidget: View {
    let kind: PlaceholderWidgetKind
    let seed: Int
    let headline: String
    let caption: String

    var body: some View {
        let shape = PlaceholderWidgetShape(kind: kind)
        PlaceholderArtwork(seed: seed)
            .overlay(alignment: kind.contentAlignment) {
                VStack(alignment: kind == .circle ? .center : .leading, spacing: DS.Spacing.xxs) {
                    Text(headline)
                        .font(DS.Typography.widgetValue)
                        .foregroundStyle(DS.Palette.widgetText)
                    Text(caption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.widgetTextSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, kind == .widePill ? DS.Spacing.xl : DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .clipShape(shape)
            .glassRim(shape)
    }
}
