import SwiftUI

struct WidgetOptionsGrid: View {
    static let slotAspects: [CGFloat] = [2.1, 1, 1, 0.5, 0.78, 1.4]

    let options: [WidgetModel]
    @Binding var selection: UUID?

    var body: some View {
        BentoLayout(spacing: DS.Spacing.lg, maxUnit: DS.Size.optionUnitMax, caption: DS.Size.optionCaption) {
            ForEach(Array(Self.arranged(options).enumerated()), id: \.offset) { index, slot in
                if let option = slot {
                    WidgetOptionCard(option: option, index: index, isSelected: selection == option.id) {
                        selection = selection == option.id ? nil : option.id
                    }
                } else {
                    Color.clear
                }
            }
        }
    }

    static func arranged(_ options: [WidgetModel]) -> [WidgetModel?] {
        var remaining = options
        var slots = [WidgetModel?](repeating: nil, count: slotAspects.count)
        func aspect(_ model: WidgetModel) -> CGFloat {
            let size = model.resolvedSize
            return size.height > 0 ? size.width / size.height : 1
        }
        func take(slot: Int) {
            guard !remaining.isEmpty, slot < slots.count else { return }
            let target = log(slotAspects[slot])
            guard let best = remaining.indices.min(by: { abs(log(aspect(remaining[$0])) - target) < abs(log(aspect(remaining[$1])) - target) }) else { return }
            slots[slot] = remaining.remove(at: best)
        }
        for slot in [3, 0, 5, 4, 1, 2] {
            take(slot: slot)
        }
        return slots
    }
}

struct WidgetOptionsSkeleton: View {
    var body: some View {
        BentoLayout(spacing: DS.Spacing.lg, maxUnit: DS.Size.optionUnitMax, caption: DS.Size.optionCaption) {
            ForEach(0..<WidgetDesignSchema.optionCount, id: \.self) { index in
                LayerPulse(
                    color: DS.Palette.skeleton,
                    cornerRadius: DS.Radius.lg,
                    minimumOpacity: Float(DS.Interaction.skeletonPulseOpacity),
                    duration: DS.Motion.shimmerDuration * 2,
                    delay: Double(index) * DS.Motion.optionStaggerStep * 2
                )
                .padding(.bottom, DS.Size.optionCaption)
                .appearAnimation(.smooth, index: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Designing options")
    }
}

struct BentoLayout: Layout {
    var spacing: CGFloat
    var maxUnit: CGFloat
    var caption: CGFloat = 0

    private func unit(for width: CGFloat) -> CGFloat {
        max(min(((width - spacing * 3) / 4).rounded(.down), maxUnit), 0)
    }

    private func frames(unit: CGFloat) -> [CGRect] {
        let s = spacing
        let row = unit + caption
        let tall = row * 2 + s
        let upperHeight = (row * 1.3).rounded()
        return [
            CGRect(x: 0, y: 0, width: unit * 2 + s, height: row),
            CGRect(x: 0, y: row + s, width: unit, height: row),
            CGRect(x: unit + s, y: row + s, width: unit, height: row),
            CGRect(x: (unit + s) * 2, y: 0, width: unit, height: tall),
            CGRect(x: (unit + s) * 3, y: 0, width: unit, height: upperHeight),
            CGRect(x: (unit + s) * 3, y: upperHeight + s, width: unit, height: tall - upperHeight - s)
        ]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (maxUnit * 4 + spacing * 3)
        let unit = unit(for: width)
        return CGSize(width: unit * 4 + spacing * 3, height: (unit + caption) * 2 + spacing)
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
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovering = false
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        VStack(spacing: 0) {
            WidgetTile(model: option)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DS.Spacing.xs)
            VStack(spacing: DS.Spacing.xxs) {
                Text(option.name)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("\(option.shape.title) · \(option.size.preset.title)")
                    .font(DS.Typography.micro)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.optionCaption)
        }
        .background {
            if isSelected {
                shape.fill(DS.Palette.fillSelected)
            } else if isHovering {
                shape.fill(DS.Palette.fillHover)
            }
        }
        .overlay {
            shape
                .strokeBorder(DS.Palette.focusGlow, lineWidth: DS.Stroke.focus)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
        .scaleEffect(isHovering ? DS.Interaction.cardHoverScale : 1)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isHovering)
        .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: isSelected)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : DS.Interaction.appearScale)
        .offset(y: isVisible || reduceMotion ? 0 : DS.Interaction.appearOffset * 2)
        .onAppear {
            withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion).delay(reduceMotion ? 0 : Double(index) * DS.Motion.optionStaggerStep)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.name), \(option.shape.title), \(option.size.preset.title)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
