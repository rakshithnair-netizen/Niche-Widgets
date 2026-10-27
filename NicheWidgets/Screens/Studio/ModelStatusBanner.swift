import SwiftUI
import AppKit

struct ModelStatusBanner: View {
    let health: ModelHealth
    let onRetry: () -> Void
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch health {
        case .modelMissing: "Download the local model"
        default: "Start the local model"
        }
    }

    private var message: String {
        switch health {
        case .modelMissing(let name): "\(name) isn't installed in Ollama yet. Run this in Terminal, then retry."
        default: "Ollama isn't running on this Mac. Run this in Terminal, then retry."
        }
    }

    private var command: String {
        switch health {
        case .modelMissing(let name): "ollama pull \(name)"
        default: "ollama serve"
        }
    }

    var body: some View {
        GlassCard(padding: DS.Spacing.md) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: health == .serverNotRunning ? "bolt.horizontal.circle" : "arrow.down.circle")
                    .font(DS.Typography.iconLarge)
                    .foregroundStyle(DS.Palette.warning)
                    .frame(width: DS.Size.bannerIcon, height: DS.Size.bannerIcon)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                    commandChip
                }
                Spacer(minLength: DS.Spacing.md)
                GlassButton("Retry", systemImage: "arrow.clockwise", variant: .secondary, action: onRetry)
            }
        }
    }

    private var commandChip: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
        return Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            withAnimation(DS.Motion.snappy.animation(reduceMotion: reduceMotion)) { copied = true }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(command)
                    .font(DS.Typography.caption.monospaced())
                    .foregroundStyle(DS.Palette.textPrimary)
                    .textSelection(.enabled)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(DS.Typography.micro)
                    .foregroundStyle(copied ? DS.Palette.success : DS.Palette.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(shape.fill(DS.Palette.fillHover))
            .glassRim(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .help("Copy command")
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(DS.Motion.snappy.animation(reduceMotion: reduceMotion)) { copied = false }
        }
    }
}

struct ExamplePromptChips: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                PromptChip(title: prompt) { onSelect(prompt) }
                    .appearAnimation(.bouncy, index: index + 2)
            }
        }
    }
}

private struct PromptChip: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = Capsule()
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkle")
                    .font(DS.Typography.micro)
                    .foregroundStyle(DS.Palette.accent)
                Text(title)
                    .font(DS.Typography.bodyEmphasis)
                    .foregroundStyle(DS.Palette.textPrimary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: DS.Size.controlHeight)
            .background(shape.fill(Color.white.opacity(isHovering ? DS.Interaction.hoverHighlight : 0)))
            .glassEffect(.regular.tint(DS.Glass.secondary), in: shape)
            .glassRim(shape, strength: isHovering ? 1 : DS.Interaction.restRim)
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .scaleEffect(isHovering ? DS.Interaction.cardHoverScale : 1)
        .onHover { isHovering = $0 }
        .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isHovering)
    }
}
