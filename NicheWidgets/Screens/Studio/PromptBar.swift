import SwiftUI

struct PromptBar: View {
    @Binding var text: String
    @Binding var hasAttachment: Bool
    let onSend: () -> Void
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            GlassEffectContainer(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    if hasAttachment {
                        AttachmentChip {
                            withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
                                hasAttachment = false
                            }
                        }
                        .glassEffectID("attachment", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                    }
                }
            }
            GlassTextField("Describe a vibe, or attach an image", text: $text, onSubmit: onSend) {
                GlassButton(systemImage: "photo.badge.plus", label: "Attach image") {
                    withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
                        hasAttachment.toggle()
                    }
                }
            } trailing: {
                GlassButton(systemImage: "arrow.up", label: "Send", variant: .iconProminent, action: onSend)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}

private struct AttachmentChip: View {
    let onRemove: () -> Void

    var body: some View {
        let shape = Capsule()
        HStack(spacing: DS.Spacing.sm) {
            PlaceholderArtwork(seed: 4)
                .frame(width: DS.Size.controlHeightSmall - DS.Spacing.xs, height: DS.Size.controlHeightSmall - DS.Spacing.xs)
                .clipShape(Circle())
            Text("theme-image.png")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(DS.Typography.micro)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .frame(width: DS.Size.controlHeightSmall - DS.Spacing.sm, height: DS.Size.controlHeightSmall - DS.Spacing.sm)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Remove attachment")
        }
        .padding(.leading, DS.Spacing.xs)
        .padding(.trailing, DS.Spacing.sm)
        .frame(height: DS.Size.controlHeightSmall + DS.Spacing.xs)
        .glassEffect(.regular.tint(DS.Glass.raised), in: shape)
        .glassRim(shape)
    }
}
