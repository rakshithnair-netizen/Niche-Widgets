import SwiftUI

enum GlassButtonVariant: Hashable {
    case primary, secondary, icon, iconProminent

    var isIcon: Bool { self == .icon || self == .iconProminent }
    var isProminent: Bool { self == .primary || self == .iconProminent }
}

struct GlassButton: View {
    private let title: String?
    private let systemImage: String?
    private let accessibilityText: String
    private let variant: GlassButtonVariant
    private let glassID: String?
    private let namespace: Namespace.ID?
    private let action: () -> Void

    init(_ title: String, systemImage: String? = nil, variant: GlassButtonVariant = .primary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityText = title
        self.variant = variant
        self.glassID = nil
        self.namespace = nil
        self.action = action
    }

    init(systemImage: String, label: String, variant: GlassButtonVariant = .icon, glassID: String? = nil, in namespace: Namespace.ID? = nil, action: @escaping () -> Void) {
        self.title = nil
        self.systemImage = systemImage
        self.accessibilityText = label
        self.variant = variant
        self.glassID = glassID
        self.namespace = namespace
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DS.Typography.icon)
                }
                if let title {
                    Text(title)
                        .font(DS.Typography.label)
                }
            }
        }
        .buttonStyle(GlassButtonStyle(variant: variant, glassID: glassID, namespace: namespace))
        .accessibilityLabel(accessibilityText)
        .help(title == nil ? accessibilityText : "")
    }
}

struct GlassButtonStyle: ButtonStyle {
    var variant: GlassButtonVariant = .primary
    var glassID: String? = nil
    var namespace: Namespace.ID? = nil

    func makeBody(configuration: Configuration) -> some View {
        GlassButtonChrome(label: configuration.label, isPressed: configuration.isPressed, variant: variant, glassID: glassID, namespace: namespace)
    }
}

private struct GlassButtonChrome<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let variant: GlassButtonVariant
    let glassID: String?
    let namespace: Namespace.ID?
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

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Size.controlHeight / 2, style: .continuous)
    }

    private var scale: CGFloat {
        switch state {
        case .hover: DS.Interaction.hoverScale
        case .pressed: DS.Interaction.pressScale
        default: 1
        }
    }

    private var brightness: Double {
        switch state {
        case .hover: DS.Interaction.hoverBrightness
        case .pressed: DS.Interaction.pressBrightness
        default: 0
        }
    }

    private var highlight: Double {
        switch state {
        case .hover: DS.Interaction.hoverHighlight
        case .pressed: DS.Interaction.pressHighlight
        default: 0
        }
    }

    var body: some View {
        label
            .foregroundStyle(variant.isProminent ? DS.Palette.textOnPrimary : DS.Palette.textPrimary)
            .padding(.horizontal, variant.isIcon ? 0 : DS.Spacing.lg)
            .frame(width: variant.isIcon ? DS.Size.controlHeight : nil, height: DS.Size.controlHeight)
            .background(shape.fill(Color.white.opacity(highlight)))
            .glassEffect(.regular.tint(variant.isProminent ? DS.Glass.primary : DS.Glass.secondary), in: shape)
            .glassID(glassID, in: namespace)
            .glassRim(shape, strength: state == .rest || state == .disabled ? DS.Interaction.restRim : 1)
            .contentShape(shape)
            .scaleEffect(scale)
            .brightness(brightness)
            .opacity(state == .disabled ? DS.Interaction.disabledOpacity : 1)
            .onHover { isHovering = $0 }
            .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: state)
    }
}
