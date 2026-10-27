import SwiftUI

enum GlassIntensity: String, CaseIterable {
    case subtle, balanced, vivid

    var title: String { rawValue.capitalized }
}

enum PinsPerSearch: Int, CaseIterable {
    case low = 100, medium = 150, high = 200

    var title: String { "\(rawValue)" }
}

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var showMenuBarIcon = true
    @State private var glassIntensity = GlassIntensity.balanced
    @State private var reduceTransparency = false
    @State private var pauseWhenHidden = true
    @State private var unloadModels = true
    @State private var pinsPerSearch = PinsPerSearch.medium

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                ScreenHeader("Settings", subtitle: "Placeholder preferences for this build")
                    .padding(.bottom, DS.Spacing.sm)
                settingsCard("General", index: 0) {
                    GlassToggle("Launch at login", subtitle: "Open Niche Widgets when you sign in", isOn: $launchAtLogin)
                    GlassDivider()
                    GlassToggle("Show menu bar icon", subtitle: "Quick access to edit mode", isOn: $showMenuBarIcon)
                }
                settingsCard("Appearance", index: 1) {
                    row("Glass intensity", subtitle: "How much of the desktop shows through") {
                        GlassSegmentedControl(GlassIntensity.allCases, selection: $glassIntensity) { $0.title }
                    }
                    GlassDivider()
                    GlassToggle("Reduce transparency", subtitle: "Use a solid matte background", isOn: $reduceTransparency)
                }
                settingsCard("Performance", index: 2) {
                    GlassToggle("Pause when hidden", subtitle: "Stop timers while the desktop is covered", isOn: $pauseWhenHidden)
                    GlassDivider()
                    GlassToggle("Unload models after search", subtitle: "Free memory when idle", isOn: $unloadModels)
                    GlassDivider()
                    row("Pins per search", subtitle: "More pins, better ranking, slower search") {
                        GlassSegmentedControl(PinsPerSearch.allCases, selection: $pinsPerSearch) { $0.title }
                    }
                }
            }
            .frame(maxWidth: DS.Size.settingsMaxWidth, alignment: .leading)
            .padding(DS.Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func settingsCard<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(title)
                .padding(.horizontal, DS.Spacing.xs)
            GlassCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    content()
                }
            }
        }
        .appearAnimation(.smooth, index: index)
    }

    private func row<Accessory: View>(_ title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyEmphasis)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            Spacer(minLength: DS.Spacing.md)
            accessory()
        }
    }
}
