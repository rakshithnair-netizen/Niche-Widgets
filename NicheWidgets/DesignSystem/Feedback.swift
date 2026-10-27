import SwiftUI

struct ShimmerModifier: ViewModifier {
    var isActive: Bool
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    GeometryReader { proxy in
                        let band = proxy.size.width * DS.Motion.shimmerBand
                        LinearGradient(colors: [.clear, DS.Palette.shimmer, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: band)
                            .offset(x: -band + phase * (proxy.size.width + band))
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .onAppear {
                        phase = 0
                        withAnimation(.linear(duration: DS.Motion.shimmerDuration).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
    }
}

extension View {
    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

struct LoadingShimmer: View {
    var lines: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(0..<lines, id: \.self) { index in
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(DS.Palette.skeleton)
                    .frame(height: DS.Size.skeletonLine)
                    .padding(.trailing, index == lines - 1 ? DS.Size.skeletonTrailing : 0)
            }
        }
        .shimmering()
        .accessibilityLabel("Loading")
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: systemImage)
                .font(DS.Typography.iconLarge)
                .foregroundStyle(DS.Palette.textSecondary)
                .frame(width: DS.Size.emptyIcon, height: DS.Size.emptyIcon)
                .glassEffect(.regular.tint(DS.Glass.raised), in: Circle())
                .glassRim(Circle())
            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(message)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: DS.Size.emptyMessageWidth)
            }
            if let actionTitle, let action {
                GlassButton(actionTitle, variant: .secondary, action: action)
            }
        }
        .padding(DS.Spacing.xxl)
        .appearAnimation(.smooth)
    }
}
