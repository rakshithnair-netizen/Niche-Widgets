import SwiftUI

struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    let text: String
    var attachmentSeed: Int? = nil

    static var samples: [ChatMessage] {
        [
            ChatMessage(role: .user, text: "Soft brutalist concrete, morning fog, muted sage accents.", attachmentSeed: 1),
            ChatMessage(role: .assistant, text: "Here are six directions in different shapes. Pick one to refine, or describe what to change."),
            ChatMessage(role: .user, text: "Make the clock feel calmer and lower contrast."),
            ChatMessage(role: .assistant, text: "Placeholder reply. The local model connects in a later step.")
        ]
    }
}

enum OptionSizeFilter: String, CaseIterable {
    case all, small, large

    var title: String { rawValue.capitalized }
}

struct StudioView: View {
    @State private var messages = ChatMessage.samples
    @State private var draft = ""
    @State private var hasAttachment = false
    @State private var sizeFilter = OptionSizeFilter.all
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ScreenHeader("Studio", subtitle: "Describe an aesthetic or drop a theme image") {
                GlassButton("New Session", systemImage: "plus", variant: .secondary) {
                    withAnimation(DS.Motion.smooth.animation(reduceMotion: reduceMotion)) {
                        messages = []
                        draft = ""
                        hasAttachment = false
                    }
                }
            }
            HStack(alignment: .top, spacing: DS.Spacing.xl) {
                chatColumn
                    .frame(width: DS.Size.chatColumnWidth)
                optionsColumn
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(DS.Spacing.lg)
    }

    private var chatColumn: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                if messages.isEmpty {
                    EmptyStateView(
                        systemImage: "text.bubble",
                        title: "Start with a vibe",
                        message: "Type a few words or attach a theme image to get widget options."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.md) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                ChatBubble(message: message)
                                    .appearAnimation(.bouncy, index: index)
                                    .transition(.chatBubble(isUser: message.role == .user, reduceMotion: reduceMotion))
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.bottom)
                }
            }
            .frame(maxHeight: .infinity)
            PromptBar(text: $draft, hasAttachment: $hasAttachment, onSend: send)
        }
    }

    private var optionsColumn: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Options")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text("Six placeholder layouts")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer(minLength: DS.Spacing.lg)
                GlassSegmentedControl(OptionSizeFilter.allCases, selection: $sizeFilter) { $0.title }
            }
            ScrollView {
                WidgetOptionsGrid()
                    .padding(DS.Spacing.sm)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || hasAttachment else { return }
        let message = ChatMessage(role: .user, text: trimmed.isEmpty ? "Theme image" : trimmed, attachmentSeed: hasAttachment ? 4 : nil)
        withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
            messages.append(message)
            draft = ""
            hasAttachment = false
        }
    }
}

extension AnyTransition {
    static func chatBubble(isUser: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .scale(scale: DS.Interaction.bubbleScale, anchor: isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
            removal: .opacity
        )
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: DS.Radius.lg,
                bottomLeading: isUser ? DS.Radius.lg : DS.Radius.xs,
                bottomTrailing: isUser ? DS.Radius.xs : DS.Radius.lg,
                topTrailing: DS.Radius.lg
            ),
            style: .continuous
        )
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: DS.Spacing.xxl) }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let seed = message.attachmentSeed {
                    PlaceholderArtwork(seed: seed)
                        .frame(width: DS.Size.attachmentThumb, height: DS.Size.attachmentThumb)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .glassRim(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                Text(message.text)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: DS.Size.bubbleMaxWidth, alignment: .leading)
            .glassEffect(.regular.tint(isUser ? DS.Glass.bubbleUser : DS.Glass.bubbleAssistant), in: shape)
            .glassRim(shape)
            if !isUser { Spacer(minLength: DS.Spacing.xxl) }
        }
    }
}
