import SwiftUI

private enum GalleryState: CaseIterable, Identifiable {
    case rest, hover, pressed, disabled

    var id: Self { self }

    var title: String {
        switch self {
        case .rest: "Rest"
        case .hover: "Hover"
        case .pressed: "Pressed"
        case .disabled: "Disabled"
        }
    }

    var forced: GlassInteractionState? {
        switch self {
        case .rest: .rest
        case .hover: .hover
        case .pressed: .pressed
        case .disabled: nil
        }
    }
}

private enum FieldState: CaseIterable, Identifiable {
    case rest, hover, focused, filled

    var id: Self { self }

    var title: String {
        switch self {
        case .rest: "Rest"
        case .hover: "Hover"
        case .focused: "Focused"
        case .filled: "Filled"
        }
    }

    var forced: GlassInteractionState {
        switch self {
        case .rest, .filled: .rest
        case .hover: .hover
        case .focused: .focused
        }
    }
}

private enum GallerySegment: String, CaseIterable {
    case day, week, month

    var title: String { rawValue.capitalized }
}

struct ComponentsGalleryView: View {
    @State private var liveText = ""
    @State private var segment = GallerySegment.week
    @State private var secondSegment = GallerySegment.day
    @State private var liveToggle = true
    @State private var sidebarSelection = AppScreen.library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                ScreenHeader("Components", subtitle: "Every design system component in every state")
                section("Glass Button", index: 0) { buttons }
                section("Glass Text Field", index: 1) { textFields }
                section("Glass Toggle", index: 2) { toggles }
                section("Glass Segmented Control", index: 3) { segmentedControls }
                section("Glass Card", index: 4) { cards }
                section("Glass Sidebar", index: 5) { sidebar }
                section("Loading and Empty", index: 6) { feedback }
                section("Tokens", index: 7) { tokens }
            }
            .padding(DS.Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func section<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(title)
                .padding(.horizontal, DS.Spacing.xs)
            GlassCard(padding: DS.Spacing.xl) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .appearAnimation(.smooth, index: index)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.textTertiary)
    }

    private var buttons: some View {
        Grid(alignment: .leading, horizontalSpacing: DS.Spacing.xl, verticalSpacing: DS.Spacing.lg) {
            GridRow {
                caption("")
                ForEach(GalleryState.allCases) { state in
                    caption(state.title)
                }
                caption("Live")
            }
            buttonRow("Primary") { GlassButton("Generate", systemImage: "sparkles") {} }
            buttonRow("Secondary") { GlassButton("Cancel", variant: .secondary) {} }
            buttonRow("Icon") { GlassButton(systemImage: "photo.badge.plus", label: "Attach") {} }
            buttonRow("Icon Prominent") { GlassButton(systemImage: "arrow.up", label: "Send", variant: .iconProminent) {} }
        }
    }

    private func buttonRow<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        GridRow {
            caption(title)
                .frame(width: DS.Size.galleryColumn, alignment: .leading)
            ForEach(GalleryState.allCases) { state in
                content()
                    .glassForcedState(state.forced)
                    .disabled(state == .disabled)
            }
            content()
        }
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: DS.Size.galleryFieldWidth), spacing: DS.Spacing.lg)], alignment: .leading, spacing: DS.Spacing.lg) {
                ForEach(FieldState.allCases) { state in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        caption(state.title)
                        GlassTextField("Describe a vibe", text: .constant(state == .filled ? "Misty sage brutalism" : ""))
                            .glassForcedState(state.forced)
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Live with accessories")
                GlassTextField("Type here to try focus", text: $liveText) {
                    GlassButton(systemImage: "photo.badge.plus", label: "Attach") {}
                } trailing: {
                    GlassButton(systemImage: "arrow.up", label: "Send", variant: .iconProminent) {}
                        .disabled(liveText.isEmpty)
                }
            }
        }
    }

    private var toggles: some View {
        HStack(alignment: .top, spacing: DS.Spacing.xxl) {
            toggleSample("Off") { GlassToggle(isOn: .constant(false)).glassForcedState(.rest) }
            toggleSample("On") { GlassToggle(isOn: .constant(true)).glassForcedState(.rest) }
            toggleSample("Hover") { GlassToggle(isOn: .constant(true)).glassForcedState(.hover) }
            toggleSample("Pressed") { GlassToggle(isOn: .constant(false)).glassForcedState(.pressed) }
            toggleSample("Disabled") { GlassToggle(isOn: .constant(true)).disabled(true) }
            toggleSample("Live") { GlassToggle(isOn: $liveToggle) }
        }
    }

    private func toggleSample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            caption(title)
            content()
        }
    }

    private var segmentedControls: some View {
        HStack(spacing: DS.Spacing.xl) {
            GlassSegmentedControl(GallerySegment.allCases, selection: $segment) { $0.title }
            GlassSegmentedControl(GallerySegment.allCases, selection: $secondSegment) { $0.title }
                .disabled(true)
                .opacity(DS.Interaction.disabledOpacity)
        }
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            GlassCard {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Surface")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("Default tint with rim highlight and inner shadow")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassCard(tint: DS.Glass.raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Raised")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("Brighter tint for emphasis")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sidebar: some View {
        GlassSidebar(sections: [GlassSidebarSection(id: "sample", title: "Navigation", items: [AppScreen.studio, .library, .settings])], selection: $sidebarSelection)
            .frame(height: DS.Size.gallerySidebarHeight)
    }

    private var feedback: some View {
        HStack(alignment: .center, spacing: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Loading shimmer")
                LoadingShimmer()
                    .frame(width: DS.Size.galleryShimmerWidth)
            }
            EmptyStateView(
                systemImage: "square.dashed",
                title: "Nothing here yet",
                message: "Saved widgets will appear in your library.",
                actionTitle: "Open Studio",
                action: {}
            )
        }
    }

    private var tokens: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Colors")
                HStack(spacing: DS.Spacing.md) {
                    swatch(DS.Palette.textPrimary, "Primary")
                    swatch(DS.Palette.textSecondary, "Secondary")
                    swatch(DS.Palette.textTertiary, "Tertiary")
                    swatch(DS.Palette.accent, "Accent")
                    swatch(DS.Palette.success, "Success")
                    swatch(DS.Palette.danger, "Danger")
                    swatch(DS.Palette.trackOn, "Track")
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Spacing")
                HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                    ForEach(DS.Spacing.scale, id: \.name) { item in
                        VStack(spacing: DS.Spacing.xs) {
                            RoundedRectangle(cornerRadius: DS.Spacing.xxs, style: .continuous)
                                .fill(DS.Palette.accent.opacity(0.6))
                                .frame(width: item.value, height: item.value)
                            caption(item.name)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Radii")
                HStack(spacing: DS.Spacing.md) {
                    ForEach(DS.Radius.scale, id: \.name) { item in
                        VStack(spacing: DS.Spacing.xs) {
                            RoundedRectangle(cornerRadius: item.value, style: .continuous)
                                .fill(DS.Palette.fillSelected)
                                .glassRim(RoundedRectangle(cornerRadius: item.value, style: .continuous))
                                .frame(width: DS.Size.swatch, height: DS.Size.swatch)
                            caption(item.name)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                caption("Typography")
                ForEach(DS.Typography.scale, id: \.name) { item in
                    Text(item.name)
                        .font(item.font)
                        .foregroundStyle(DS.Palette.textPrimary)
                }
            }
        }
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(color)
                .glassRim(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .frame(width: DS.Size.swatch, height: DS.Size.swatch)
            caption(name)
        }
    }
}
