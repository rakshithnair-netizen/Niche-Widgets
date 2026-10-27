import SwiftUI

struct LibraryItem: Identifiable {
    let id: Int
    let name: String
    let kind: PlaceholderWidgetKind
    let headline: String
    let isFavorite: Bool
    let isRecent: Bool

    static var samples: [LibraryItem] {
        let names = ["Fog Clock", "Sage Weather", "Concrete Battery", "Morning Pages", "Focus Timer", "Ambient Player", "Dune Calendar", "Violet Notes", "Graphite Stocks", "Tide Moon", "Paper Quote", "Night Steps"]
        let headlines = ["09:41", "14°", "68%", "3/5", "25:00", "Play", "Oct 27", "Notes", "+1.2%", "Waxing", "Quote", "8,204"]
        let kinds = PlaceholderWidgetKind.allCases
        return names.indices.map { index in
            LibraryItem(
                id: index,
                name: names[index],
                kind: kinds[index % kinds.count],
                headline: headlines[index],
                isFavorite: index % 3 == 0,
                isRecent: index < 5
            )
        }
    }
}

enum LibraryFilter: String, CaseIterable {
    case all, recent, favorites

    var title: String { rawValue.capitalized }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let items = LibraryItem.samples

    private var visibleItems: [LibraryItem] {
        switch filter {
        case .all: items
        case .recent: items.filter(\.isRecent)
        case .favorites: items.filter(\.isFavorite)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ScreenHeader("Library", subtitle: "\(visibleItems.count) saved widgets") {
                GlassSegmentedControl(LibraryFilter.allCases, selection: $filter) { $0.title }
            }
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
        .padding(DS.Spacing.lg)
    }
}

private struct LibraryItemCard: View {
    let item: LibraryItem
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        let previewShape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ZStack {
                previewShape.fill(DS.Palette.fillSubtle)
                PlaceholderWidget(kind: item.kind, seed: item.id, headline: item.headline, caption: item.kind.title)
                    .aspectRatio(item.kind.aspectRatio, contentMode: .fit)
                    .padding(DS.Spacing.lg)
            }
            .aspectRatio(DS.Size.libraryPreviewAspect, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                LibraryHoverActions(isExpanded: isHovering)
                    .padding(DS.Spacing.sm)
            }
            HStack(spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.name)
                        .font(DS.Typography.bodyEmphasis)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text(item.kind.title)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer(minLength: 0)
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.accent)
                }
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
