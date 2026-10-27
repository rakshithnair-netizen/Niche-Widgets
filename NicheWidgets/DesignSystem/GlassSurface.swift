import SwiftUI
import AppKit

struct MatteGlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .hudWindow)
            DS.Glass.windowTint.opacity(DS.Glass.windowTintOpacity)
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

struct GlassRim<S: InsettableShape>: View {
    let shape: S
    var strength: Double = 1

    var body: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [DS.Palette.rimBright, DS.Palette.rimDim, DS.Palette.rimMid],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: DS.Stroke.hairline
            )
            .opacity(strength)
            .allowsHitTesting(false)
    }
}

struct GlassInnerShadow<S: Shape>: View {
    let shape: S

    var body: some View {
        ZStack {
            shape
                .stroke(DS.Shadow.inner.color, lineWidth: DS.Shadow.inner.radius * 2)
                .blur(radius: DS.Shadow.inner.radius)
                .offset(x: DS.Shadow.inner.x, y: DS.Shadow.inner.y)
            shape
                .stroke(DS.Shadow.innerGlow.color, lineWidth: DS.Shadow.innerGlow.radius * 2)
                .blur(radius: DS.Shadow.innerGlow.radius)
                .offset(x: DS.Shadow.innerGlow.x, y: DS.Shadow.innerGlow.y)
        }
        .mask(shape)
        .allowsHitTesting(false)
    }
}

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Palette.hairline)
            .frame(height: DS.Stroke.hairline)
    }
}

struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(DS.Typography.micro)
            .tracking(DS.Typography.microTracking)
            .foregroundStyle(DS.Palette.textTertiary)
    }
}

extension View {
    func glassRim<S: InsettableShape>(_ shape: S, strength: Double = 1) -> some View {
        overlay(GlassRim(shape: shape, strength: strength))
    }

    func glassInnerShadow<S: Shape>(_ shape: S) -> some View {
        overlay(GlassInnerShadow(shape: shape))
    }
}
