import SwiftUI

enum LibraryFilter: String, CaseIterable {
    case all, recent

    var title: String { rawValue.capitalized }

    static let recentCount = 6
}

enum LibraryAction: String, CaseIterable, Identifiable {
    case rename, duplicate, desktop, delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rename: "Rename"
        case .duplicate: "Duplicate"
        case .desktop: "Add to Desktop"
        case .delete: "Delete"
        }
    }

    var systemImage: String {
        switch self {
        case .rename: "pencil"
        case .duplicate: "plus.square.on.square"
        case .desktop: "macwindow.badge.plus"
        case .delete: "trash"
        }
    }
}

struct LibraryView: View {
    @State private var filter = LibraryFilter.all
    @Environment(WidgetLibrary.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleItems: [WidgetModel] {
        switch filter {
        case .all: library.widgets
        case .recent: Array(library.widgets.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(LibraryFilter.recentCount))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ScreenHeader("Library", subtitle: "\(visibleItems.count) saved widgets") {
                GlassSegmentedControl(LibraryFilter.allCases, selection: $filter) { $0.title }
            }
            if library.isLoaded && library.widgets.isEmpty {
                EmptyStateView(
                    systemImage: "square.dashed",
                    title: "Nothing here yet",
                    message: "Saved widgets will appear in your library."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: DS.Size.libraryItemMin), spacing: DS.Spacing.lg)], spacing: DS.Spacing.lg) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            LibraryItemCard(item: item)
                                .appearAnimation(.bouncy, index: index)
                                .transition(.scale(scale: DS.Interaction.appearScale).combined(with: .opacity))
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: filter)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .padding(DS.Spacing.lg)
    }
}

private struct LibraryItemCard: View {
    let item: WidgetModel
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var detail: String {
        let size = item.resolvedSize
        return "\(item.shape.title) · \(Int(size.width))×\(Int(size.height))"
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        let previewShape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ZStack {
                previewShape.fill(DS.Palette.fillSubtle)
                WidgetTile(model: item)
                    .padding(DS.Spacing.xl)
            }
            .aspectRatio(DS.Size.libraryPreviewAspect, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                LibraryHoverActions(isExpanded: isHovering)
                    .padding(DS.Spacing.sm)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(item.name)
                    .font(DS.Typography.bodyEmphasis)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .padding(DS.Spacing.sm)
        .background(shape.fill(isHovering ? DS.Palette.fillHover : DS.Palette.fillSubtle))
        .glassRim(shape, strength: isHovering ? 1 : DS.Interaction.restRim)
        .scaleEffect(isHovering ? DS.Interaction.cardHoverScale : 1)
        .dsShadow(isHovering ? DS.Shadow.lifted : DS.Shadow.soft)
        .onHover { isHovering = $0 }
        .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: isHovering)
    }
}

private struct LibraryHoverActions: View {
    let isExpanded: Bool
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                if isExpanded {
                    ForEach(LibraryAction.allCases) { action in
                        GlassButton(systemImage: action.systemImage, label: action.title, glassID: action.id, in: glassNamespace) {}
                    }
                } else {
                    GlassButton(systemImage: "ellipsis", label: "Actions", glassID: "more", in: glassNamespace) {}
                }
            }
        }
    }
}
