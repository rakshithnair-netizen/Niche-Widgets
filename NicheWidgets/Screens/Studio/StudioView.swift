import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Environment(ChatSession.self) private var session
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ScreenHeader("Studio", subtitle: "Describe an aesthetic or drop a theme image") {
                GlassButton("New Chat", systemImage: "plus", variant: .secondary) {
                    withAnimation(DS.Motion.smooth.animation(reduceMotion: reduceMotion)) {
                        session.newChat()
                    }
                }
                .disabled(session.messages.isEmpty && session.attachments.isEmpty && session.draft.isEmpty)
            }
            if session.health.needsAttention {
                ModelStatusBanner(health: session.health) {
                    Task { await session.refreshHealth() }
                }
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: DS.Interaction.appearScale, anchor: .top)))
            }
            HStack(alignment: .top, spacing: DS.Spacing.xl) {
                chatColumn
                    .frame(width: DS.Size.chatColumnWidth)
                OptionsColumn(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(DS.Spacing.lg)
        .overlay {
            let shape = RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
            shape
                .strokeBorder(DS.Palette.focusGlow, style: StrokeStyle(lineWidth: DS.Stroke.focus, dash: DS.Size.dash))
                .background(shape.fill(DS.Palette.fillSubtle))
                .padding(DS.Size.dropInset)
                .opacity(isDropTargeted ? 1 : 0)
                .scaleEffect(isDropTargeted || reduceMotion ? 1 : DS.Interaction.screenScale)
                .allowsHitTesting(false)
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted, perform: handleDrop)
        .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: session.health.needsAttention)
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isDropTargeted)
        .task(id: session.settings.resolvedModel) { await session.refreshHealth() }
        .task(id: session.health.needsAttention) {
            guard session.health.needsAttention else { return }
            await session.pollHealthWhileUnavailable()
        }
    }

    private var chatColumn: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                if session.messages.isEmpty {
                    VStack(spacing: DS.Spacing.lg) {
                        EmptyStateView(
                            systemImage: "text.bubble",
                            title: "Start with a vibe",
                            message: "Type a few words or attach a theme image to get six widget options."
                        )
                        ExamplePromptChips(prompts: ChatSession.examplePrompts) { prompt in
                            session.useExample(prompt)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    ChatMessageList(session: session)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: session.messages.isEmpty)
            PromptBar(session: session)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers.prefix(ImageAttachmentLoader.maxAttachments) {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in session.attach(urls: [url]) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                accepted = true
                let name = provider.suggestedName ?? "Dropped image"
                _ = provider.loadDataRepresentation(for: .image) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in session.attach(data: data, name: name) }
                }
            }
        }
        return accepted
    }
}

private struct OptionsColumn: View {
    @Bindable var session: ChatSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            ScrollView {
                ZStack(alignment: .topLeading) {
                    if session.isGenerating {
                        WidgetOptionsSkeleton()
                            .transition(.opacity)
                    } else if let displayed = session.displayed {
                        WidgetOptionsGrid(options: displayed.result.options, selection: $session.selectedOptionID)
                            .id(displayed.id)
                            .transition(.opacity)
                    } else {
                        EmptyStateView(
                            systemImage: "square.grid.2x2",
                            title: "No options yet",
                            message: "Six widget designs in different shapes and sizes appear here."
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.xxxl)
                        .transition(.opacity)
                    }
                }
                .padding(DS.Spacing.sm)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: session.isGenerating)
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: session.displayed?.id)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Options")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer(minLength: DS.Spacing.lg)
                if let displayed = session.displayed, !session.isGenerating {
                    PaletteStrip(colors: displayed.result.palette)
                        .transition(.opacity)
                }
            }
            if let displayed = session.displayed, !session.isGenerating {
                Text(displayed.result.aesthetic)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineLimit(2)
                    .transition(.opacity)
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(Array(displayed.result.searchTerms.enumerated()), id: \.offset) { index, term in
                            SearchTermChip(term: term)
                                .appearAnimation(.smooth, index: index)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
                .scrollIndicators(.never)
                .id(displayed.id)
                .transition(.opacity)
            } else {
                Text(session.isGenerating ? "Designing six directions…" : "Pick an example or describe a vibe")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .contentTransition(.opacity)
            }
        }
        .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: session.isGenerating)
    }
}

private struct SearchTermChip: View {
    let term: String

    var body: some View {
        let shape = Capsule()
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(DS.Typography.micro)
            Text(term)
                .font(DS.Typography.caption)
        }
        .foregroundStyle(DS.Palette.textSecondary)
        .padding(.horizontal, DS.Spacing.sm)
        .frame(height: DS.Size.controlHeightSmall)
        .glassEffect(.regular.tint(DS.Glass.surface), in: shape)
        .glassRim(shape, strength: DS.Interaction.restRim)
    }
}
