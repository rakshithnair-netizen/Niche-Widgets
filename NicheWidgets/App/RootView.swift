import SwiftUI

enum AppScreen: String, CaseIterable, GlassSidebarItem {
    case studio, library, settings, gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: "Studio"
        case .library: "Library"
        case .settings: "Settings"
        case .gallery: "Components"
        }
    }

    var systemImage: String {
        switch self {
        case .studio: "sparkles"
        case .library: "square.grid.2x2"
        case .settings: "gearshape"
        case .gallery: "swatchpalette"
        }
    }

    var shortcut: KeyEquivalent? {
        switch self {
        case .studio: "1"
        case .library: "2"
        case .settings: "3"
        case .gallery: "4"
        }
    }

    static var sections: [GlassSidebarSection<AppScreen>] {
        [
            GlassSidebarSection(id: "main", title: "Workspace", items: [.studio, .library, .settings]),
            GlassSidebarSection(id: "design", title: "Design System", items: [.gallery])
        ]
    }
}

struct RootView: View {
    @State private var selection: AppScreen = .studio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            GlassSidebar(sections: AppScreen.sections, selection: $selection) {
                SidebarBrand()
                    .padding(.top, DS.Size.titlebarInset)
            } footer: {
                SidebarFooter()
            }
            ZStack {
                screen
                    .id(selection)
                    .transition(.screen(reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: selection)
        }
        .padding(DS.Spacing.sm)
    }

    @ViewBuilder
    private var screen: some View {
        switch selection {
        case .studio: StudioView()
        case .library: LibraryView()
        case .settings: SettingsView()
        case .gallery: ComponentsGalleryView()
        }
    }
}

private struct SidebarBrand: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "square.on.square.squareshape.controlhandles")
                .font(DS.Typography.icon)
                .foregroundStyle(DS.Palette.accent)
            Text("Niche Widgets")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Palette.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}

private struct SidebarFooter: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(DS.Palette.textTertiary)
                .frame(width: DS.Size.statusDot, height: DS.Size.statusDot)
            Text("Version \(version)")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }
}
