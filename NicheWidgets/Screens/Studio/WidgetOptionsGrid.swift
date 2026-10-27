import SwiftUI

struct WidgetOptionsGrid: View {
    static let slotShapes: [WidgetShape] = [.widePill, .square, .circle, .tallCard, .roundedRect, .squircle]

    let options: [WidgetModel]

    var body: some View {
        BentoLayout(spacing: DS.Spacing.lg, maxUnit: DS.Size.optionUnitMax) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                WidgetOptionCard(option: option, index: index)
            }
        }
    }
}

struct BentoLayout: Layout {
    var spacing: CGFloat
    var maxUnit: CGFloat

    private func unit(for width: CGFloat) -> CGFloat {
        max(min(((width - spacing * 3) / 4).rounded(.down), maxUnit), 0)
    }

    private func frames(unit: CGFloat) -> [CGRect] {
        let s = spacing
        let tall = unit * 2 + s
        let roundedHeight = (unit * 1.3).rounded()
        return [
            CGRect(x: 0, y: 0, width: unit * 2 + s, height: unit),
            CGRect(x: 0, y: unit + s, width: unit, height: unit),
            CGRect(x: unit + s, y: unit + s, width: unit, height: unit),
            CGRect(x: (unit + s) * 2, y: 0, width: unit, height: tall),
            CGRect(x: (unit + s) * 3, y: 0, width: unit, height: roundedHeight),
            CGRect(x: (unit + s) * 3, y: roundedHeight + s, width: unit, height: tall - roundedHeight - s)
        ]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (maxUnit * 4 + spacing * 3)
        let unit = unit(for: width)
        return CGSize(width: unit * 4 + spacing * 3, height: unit * 2 + spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let unit = unit(for: bounds.width)
        for (subview, frame) in zip(subviews, frames(unit: unit)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}

private struct WidgetOptionCard: View {
    let option: WidgetModel
    let index: Int
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WidgetTile(model: option)
            .overlay(alignment: option.shape == .circle ? .bottom : .topTrailing) {
                if isHovering {
                    GlassButton(systemImage: "plus", label: "Add to Library", variant: .iconProminent) {}
                        .padding(DS.Spacing.sm)
                        .transition(.scale(scale: DS.Interaction.appearScale).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isHovering ? DS.Interaction.cardHoverScale : 1)
            .onHover { isHovering = $0 }
            .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isHovering)
            .appearAnimation(.bouncy, index: index)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(option.shape.title) option, \(option.name)")
    }
}
