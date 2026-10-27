import SwiftUI

enum GlassInteractionState: Hashable {
    case rest, hover, pressed, focused, disabled
}

extension EnvironmentValues {
    @Entry var glassForcedState: GlassInteractionState? = nil
}

extension View {
    func glassForcedState(_ state: GlassInteractionState?) -> some View {
        environment(\.glassForcedState, state)
    }

    func appearAnimation(_ motion: DS.Motion = .bouncy, index: Int = 0) -> some View {
        modifier(AppearModifier(motion: motion, delay: Double(index) * DS.Motion.staggerStep))
    }

    @ViewBuilder
    func glassID(_ id: String?, in namespace: Namespace.ID?) -> some View {
        if let id, let namespace {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

struct AppearModifier: ViewModifier {
    let motion: DS.Motion
    let delay: Double
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible || reduceMotion ? 1 : DS.Interaction.appearScale)
            .offset(y: isVisible || reduceMotion ? 0 : DS.Interaction.appearOffset)
            .onAppear {
                withAnimation(motion.animation(reduceMotion: reduceMotion).delay(reduceMotion ? 0 : delay)) {
                    isVisible = true
                }
            }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct PressableBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .scaleEffect(isPressed ? DS.Interaction.subtlePressScale : 1)
            .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isPressed)
    }
}

extension AnyTransition {
    static func screen(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: DS.Interaction.screenScale))
                .combined(with: .offset(y: DS.Interaction.appearOffset)),
            removal: .opacity
        )
    }
}
