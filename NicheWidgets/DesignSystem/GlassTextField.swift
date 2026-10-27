import SwiftUI

struct GlassTextField<Leading: View, Trailing: View>: View {
    private let placeholder: String
    @Binding private var text: String
    private let onSubmit: () -> Void
    private let leading: Leading
    private let trailing: Trailing
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @Environment(\.glassForcedState) private var forcedState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void = {}, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
        self.leading = leading()
        self.trailing = trailing()
    }

    private var showsFocus: Bool {
        if let forcedState { return forcedState == .focused }
        return isFocused
    }

    private var showsHover: Bool {
        if let forcedState { return forcedState == .hover }
        return isHovering
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            leading
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Palette.textTertiary)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
                TextField("", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textPrimary)
                    .tint(DS.Palette.accent)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onSubmit(onSubmit)
            }
            .padding(.horizontal, DS.Spacing.xs)
            .frame(minHeight: DS.Size.controlHeight)
            trailing
        }
        .padding(DS.Spacing.sm)
        .background(shape.fill(Color.white.opacity(showsHover && !showsFocus ? DS.Interaction.hoverHighlight / 2 : 0)))
        .glassEffect(.regular.tint(DS.Glass.surface), in: shape)
        .glassInnerShadow(shape)
        .glassRim(shape, strength: showsFocus ? 0 : 1)
        .overlay(
            shape
                .strokeBorder(DS.Palette.focusGlow, lineWidth: DS.Stroke.focus)
                .opacity(showsFocus ? 1 : 0)
                .allowsHitTesting(false)
        )
        .shadow(color: showsFocus ? DS.Shadow.focus.color : .clear, radius: DS.Shadow.focus.radius)
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .onHover { isHovering = $0 }
        .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: showsFocus)
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: showsHover)
    }
}

extension GlassTextField where Leading == EmptyView, Trailing == EmptyView {
    init(_ placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void = {}) {
        self.init(placeholder, text: text, onSubmit: onSubmit, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}
