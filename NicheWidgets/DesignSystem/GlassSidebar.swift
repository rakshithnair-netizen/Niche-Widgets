import SwiftUI

protocol GlassSidebarItem: Hashable, Identifiable {
    var title: String { get }
    var systemImage: String { get }
    var shortcut: KeyEquivalent? { get }
}

struct GlassSidebarSection<Item: GlassSidebarItem>: Identifiable {
    let id: String
    let title: String?
    let items: [Item]
}

struct GlassSidebar<Item: GlassSidebarItem, Header: View, Footer: View>: View {
    private let sections: [GlassSidebarSection<Item>]
    @Binding private var selection: Item
    private let header: Header
    private let footer: Footer
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(sections: [GlassSidebarSection<Item>], selection: Binding<Item>, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.sections = sections
        self._selection = selection
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    if let title = section.title {
                        SectionLabel(title)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.xs)
                    }
                    ForEach(section.items) { item in
                        GlassSidebarRow(item: item, isSelected: item == selection, namespace: namespace) {
                            withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
                                selection = item
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(DS.Spacing.sm)
        .frame(width: DS.Size.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular.tint(DS.Glass.surface), in: shape)
        .glassInnerShadow(shape)
        .glassRim(shape)
    }
}

extension GlassSidebar where Header == EmptyView, Footer == EmptyView {
    init(sections: [GlassSidebarSection<Item>], selection: Binding<Item>) {
        self.init(sections: sections, selection: selection, header: { EmptyView() }, footer: { EmptyView() })
    }
}

private struct GlassSidebarRow<Item: GlassSidebarItem>: View {
    let item: Item
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: item.systemImage)
                    .font(DS.Typography.icon)
                    .frame(width: DS.Size.sidebarIcon)
                Text(item.title)
                    .font(DS.Typography.bodyEmphasis)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? DS.Palette.textPrimary : DS.Palette.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .frame(height: DS.Size.sidebarRowHeight)
            .background {
                if isSelected {
                    shape
                        .fill(DS.Palette.fillSelected)
                        .glassRim(shape)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if isHovering {
                    shape.fill(DS.Palette.fillHover)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .keyboardShortcut(item.shortcut.map { KeyboardShortcut($0, modifiers: .command) })
        .onHover { isHovering = $0 }
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isHovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
