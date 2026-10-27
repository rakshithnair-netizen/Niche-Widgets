import SwiftUI

struct ChatMessageList: View {
    let session: ChatSession
    @State private var position = ScrollPosition(edge: .bottom)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(session.messages) { message in
                    ChatBubble(message: message, onRetry: { session.retry(message) })
                    .id(message.id)
                    .transition(.chatBubble(isUser: message.role == .user, reduceMotion: reduceMotion))
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: session.messages.count)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .onChange(of: session.messages.count) {
            withAnimation(DS.Motion.smooth.animation(reduceMotion: reduceMotion)) {
                position.scrollTo(edge: .bottom)
            }
        }
    }
}

extension AnyTransition {
    static func chatBubble(isUser: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .scale(scale: DS.Interaction.bubbleScale, anchor: isUser ? .bottomTrailing : .bottomLeading)
                .combined(with: .opacity)
                .combined(with: .offset(y: DS.Interaction.appearOffset)),
            removal: .opacity
        )
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let onRetry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                if isUser {
                    userContent
                } else {
                    assistantContent
                }
            }
            .padding(DS.Spacing.md)
            .modifier(HuggingWidth(maxWidth: DS.Size.bubbleMaxWidth))
            .glassEffect(.regular.tint(isUser ? DS.Glass.bubbleUser : DS.Glass.bubbleAssistant), in: shape)
            .glassRim(shape)
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: message.state)
            if !isUser { Spacer(minLength: DS.Spacing.xxl) }
        }
    }

    @ViewBuilder
    private var userContent: some View {
        if !message.attachments.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(message.attachments) { attachment in
                    let thumb = RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    Image(decorative: attachment.thumbnail, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: DS.Size.attachmentThumb, height: DS.Size.attachmentThumb)
                        .clipShape(thumb)
                        .glassRim(thumb)
                }
            }
            PaletteStrip(colors: message.palette)
        }
        if !message.text.isEmpty {
            bodyText(message.text)
        } else if !message.attachments.isEmpty {
            bodyText("Match these theme images")
        }
    }

    @ViewBuilder
    private var assistantContent: some View {
        switch message.state {
        case .typing:
            TypingIndicator()
                .transition(.opacity)
        case .working(let phase):
            HStack(spacing: DS.Spacing.sm) {
                LayerPulse(color: DS.Palette.accent, minimumOpacity: 0.25)
                    .frame(width: DS.Size.typingDot, height: DS.Size.typingDot)
                Text(Self.status(for: phase))
                    .font(DS.Typography.bodyEmphasis)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .id(Self.status(for: phase))
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: DS.Spacing.xs)), removal: .opacity))
            }
            .transition(.opacity)
        case .complete:
            if let result = message.result {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    bodyText(result.aesthetic)
                    PaletteStrip(colors: result.palette)
                    Text(result.options.count == 1 ? "1 option ready" : "\(result.options.count) options ready")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                .transition(.opacity)
            }
        case .stopped:
            failure("Stopped. Send again or retry when you're ready.", systemImage: "stop.circle")
        case .failed(let error):
            failure(Self.message(for: error), systemImage: "exclamationmark.bubble")
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.textPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func failure(_ text: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(DS.Typography.icon)
                    .foregroundStyle(DS.Palette.warning)
                bodyText(text)
            }
            GlassButton("Retry", systemImage: "arrow.clockwise", variant: .secondary, action: onRetry)
        }
        .transition(.opacity)
    }

    static func status(for phase: GenerationPhase) -> String {
        switch phase {
        case .thinking: "Thinking about your aesthetic…"
        case .designing(let current) where current > 0: "Designing option \(current) of \(WidgetDesignSchema.optionCount)…"
        case .designing: "Designing options…"
        case .retrying: "Tidying up the reply…"
        }
    }

    static func message(for error: DesignError) -> String {
        switch error {
        case .ollama(.serverNotRunning):
            "I can't reach the local model. Start Ollama, then retry."
        case .ollama(.modelMissing(let name)):
            "The model \(name) isn't installed yet. Pull it, then retry."
        case .ollama(.timeout):
            "The local model took too long to answer. Retry, or try a shorter prompt."
        case .ollama(.cancelled):
            "Stopped."
        case .ollama(.badResponse):
            "The local model sent something unexpected. Retry to ask again."
        case .parse:
            "I couldn't turn that reply into widgets. Retry for a fresh set."
        }
    }
}

private struct HuggingWidth: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        HuggingWidthLayout(maxWidth: maxWidth) { content }
    }
}

private struct HuggingWidthLayout: Layout {
    let maxWidth: CGFloat

    private func childProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: min(proposal.width ?? maxWidth, maxWidth), height: proposal.height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let size = child.sizeThatFits(childProposal(proposal))
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

struct PaletteStrip: View {
    let colors: [String]

    var body: some View {
        if !colors.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(Color(cgColor: HexColor.cgColor(hex)))
                        .frame(width: DS.Size.paletteSwatch, height: DS.Size.paletteSwatch)
                        .glassRim(Circle())
                        .help(hex)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Palette \(colors.joined(separator: ", "))")
        }
    }
}

struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                LayerPulse(color: DS.Palette.textSecondary, minimumOpacity: 0.25, delay: Double(index) * DS.Motion.typingDuration / 6)
                    .frame(width: DS.Size.typingDot, height: DS.Size.typingDot)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement()
        .accessibilityLabel("Working")
    }
}
