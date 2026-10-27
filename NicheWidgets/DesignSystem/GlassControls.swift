import SwiftUI

struct GlassSegmentedControl<Value: Hashable>: View {
    private let options: [Value]
    private let title: (Value) -> String
    @Binding private var selection: Value
    @Namespace private var namespace
    @State private var hovered: Value?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ options: [Value], selection: Binding<Value>, title: @escaping (Value) -> String) {
        self.options = options
        self._selection = selection
        self.title = title
    }

    var body: some View {
        let shape = Capsule()
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(DS.Spacing.xs)
        .glassEffect(.regular.tint(DS.Glass.surface), in: shape)
        .glassInnerShadow(shape)
        .glassRim(shape)
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: hovered)
    }

    private func segment(_ option: Value) -> some View {
        let isSelected = option == selection
        let thumb = Capsule()
        return Button {
            withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
                selection = option
            }
        } label: {
            Text(title(option))
                .font(DS.Typography.label)
                .foregroundStyle(isSelected ? DS.Palette.textPrimary : DS.Palette.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .frame(height: DS.Size.controlHeightSmall)
                .background {
                    if isSelected {
                        thumb
                            .fill(DS.Palette.fillSelected)
                            .glassRim(thumb)
                            .matchedGeometryEffect(id: "thumb", in: namespace)
                    } else if hovered == option {
                        thumb.fill(DS.Palette.fillHover)
                    }
                }
                .contentShape(thumb)
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering in
            if isHovering {
                hovered = option
            } else if hovered == option {
                hovered = nil
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GlassToggle: View {
    private let title: String?
    private let subtitle: String?
    @Binding private var isOn: Bool

    init(_ title: String? = nil, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            if let title {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyEmphasis)
                        .foregroundStyle(DS.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Palette.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(GlassToggleStyle(isOn: isOn, expands: title != nil))
        .accessibilityLabel(title ?? "")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct GlassToggleStyle: ButtonStyle {
    let isOn: Bool
    let expands: Bool

    func makeBody(configuration: Configuration) -> some View {
        GlassToggleBody(label: configuration.label, isOn: isOn, isPressed: configuration.isPressed, expands: expands)
    }
}

private struct GlassToggleBody<Label: View>: View {
    let label: Label
    let isOn: Bool
    let isPressed: Bool
    let expands: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.glassForcedState) private var forcedState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var state: GlassInteractionState {
        if !isEnabled { return .disabled }
        if let forcedState { return forcedState }
        if isPressed { return .pressed }
        if isHovering { return .hover }
        return .rest
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if expands {
                label.frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassSwitch(isOn: isOn, state: state)
        }
        .contentShape(Rectangle())
        .opacity(state == .disabled ? DS.Interaction.disabledOpacity : 1)
        .onHover { isHovering = $0 }
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: state)
    }
}

private struct GlassSwitch: View {
    let isOn: Bool
    let state: GlassInteractionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let track = Capsule()
        let knob = Capsule()
        let stretch = state == .pressed ? DS.Interaction.knobStretch : 1
        ZStack(alignment: isOn ? .trailing : .leading) {
            track
                .fill(isOn ? DS.Palette.trackOn : DS.Palette.trackOff)
                .glassInnerShadow(track)
                .glassRim(track)
            knob
                .fill(DS.Palette.knob)
                .frame(width: DS.Size.toggleKnob * stretch, height: DS.Size.toggleKnob)
                .glassEffect(.regular.tint(DS.Glass.knob), in: knob)
                .dsShadow(DS.Shadow.knob)
                .scaleEffect(state == .hover ? DS.Interaction.knobHoverScale : 1)
                .padding(DS.Size.toggleInset)
        }
        .frame(width: DS.Size.toggleWidth, height: DS.Size.toggleHeight)
        .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: isOn)
    }
}
