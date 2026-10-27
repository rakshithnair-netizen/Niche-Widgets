import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PromptBar: View {
    @Bindable var session: ChatSession
    @State private var textHeight = PromptTextView.lineHeight
    @State private var isFocused = false
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !session.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(session.attachments) { attachment in
                            AttachmentThumbnail(attachment: attachment) {
                                withAnimation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion)) {
                                    session.removeAttachment(attachment)
                                }
                            }
                            .transition(.scale(scale: DS.Interaction.appearScale).combined(with: .opacity))
                        }
                    }
                    .padding(DS.Spacing.xs)
                }
                .scrollIndicators(.never)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                GlassButton(systemImage: "photo.badge.plus", label: "Attach image", action: openPanel)
                    .disabled(session.attachments.count >= ImageAttachmentLoader.maxAttachments)
                ZStack(alignment: .topLeading) {
                    if session.draft.isEmpty {
                        Text("Describe a vibe, or attach an image")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Palette.textTertiary)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                    PromptTextView(
                        text: $session.draft,
                        height: $textHeight,
                        isFocused: $isFocused,
                        focusRequest: session.focusRequest,
                        onSubmit: session.send
                    )
                    .frame(height: textHeight)
                }
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, (DS.Size.controlHeight - PromptTextView.lineHeight) / 2)
                .frame(minHeight: DS.Size.controlHeight)
                .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: textHeight)
                GlassEffectContainer(spacing: DS.Spacing.sm) {
                    if session.isGenerating {
                        GlassButton(systemImage: "stop.fill", label: "Stop", variant: .icon, glassID: "action", in: glassNamespace, action: session.stop)
                            .keyboardShortcut(".", modifiers: .command)
                            .transition(.scale(scale: DS.Interaction.appearScale).combined(with: .opacity))
                    } else {
                        GlassButton(systemImage: "arrow.up", label: "Send", variant: .iconProminent, glassID: "action", in: glassNamespace, action: session.send)
                            .disabled(!session.canSend)
                            .transition(.scale(scale: DS.Interaction.appearScale).combined(with: .opacity))
                    }
                }
            }
            .glassFieldChrome(isFocused: isFocused)
            .onTapGesture { session.focusRequest += 1 }
        }
        .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: session.isGenerating)
        .animation(DS.Motion.bouncy.animation(reduceMotion: reduceMotion), value: session.attachments)
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose theme images"
        panel.prompt = "Attach"
        let session = session
        Task { @MainActor in
            let response = await panel.begin()
            guard response == .OK else { return }
            session.attach(urls: panel.urls)
        }
    }
}

private struct AttachmentThumbnail: View {
    let attachment: ImageAttachment
    let onRemove: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
        Image(decorative: attachment.thumbnail, scale: 2)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: DS.Size.attachmentChip, height: DS.Size.attachmentChip)
            .clipShape(shape)
            .glassRim(shape)
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(DS.Typography.micro)
                        .foregroundStyle(DS.Palette.textPrimary)
                        .frame(width: DS.Size.attachmentRemove, height: DS.Size.attachmentRemove)
                        .glassEffect(.regular.tint(DS.Glass.raised), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .offset(x: DS.Spacing.xs, y: -DS.Spacing.xs)
                .opacity(isHovering ? 1 : 0.85)
                .accessibilityLabel("Remove \(attachment.name)")
            }
            .scaleEffect(isHovering ? DS.Interaction.cardHoverScale : 1)
            .onHover { isHovering = $0 }
            .animation(DS.Motion.snappy.animation(reduceMotion: reduceMotion), value: isHovering)
            .help(attachment.name)
    }
}
