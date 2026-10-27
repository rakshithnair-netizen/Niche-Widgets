import SwiftUI
import AppKit

final class PromptNSTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var onWidthChange: (() -> Void)?

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] { [.string] }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize.width != frame.width
        super.setFrameSize(newSize)
        if changed { onWidthChange?() }
    }
}

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool
    var focusRequest: Int
    var onSubmit: () -> Void

    static var font: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }

    static var lineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: font)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .none
        let textView = PromptNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textColor = NSColor.white.withAlphaComponent(0.94)
        textView.insertionPointColor = NSColor(DS.Palette.accent)
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = text
        let coordinator = context.coordinator
        textView.onFocusChange = { [weak coordinator] focused in
            coordinator?.focusChanged(focused)
        }
        textView.onWidthChange = { [weak coordinator] in
            coordinator?.recalculateHeight()
        }
        scrollView.documentView = textView
        coordinator.textView = textView
        coordinator.lastFocusRequest = focusRequest
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            coordinator.recalculateHeight()
        }
        if coordinator.lastFocusRequest != focusRequest {
            coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptTextView
        weak var textView: PromptNSTextView?
        var lastFocusRequest = 0

        init(parent: PromptTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
            recalculateHeight()
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
            if modifiers.contains(.shift) || modifiers.contains(.option) {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else {
                parent.onSubmit()
            }
            return true
        }

        func focusChanged(_ focused: Bool) {
            guard parent.isFocused != focused else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = focused
            }
        }

        func recalculateHeight() {
            guard let textView, let container = textView.textContainer, let layoutManager = textView.layoutManager else { return }
            layoutManager.ensureLayout(for: container)
            let line = PromptTextView.lineHeight
            let used = max(layoutManager.usedRect(for: container).height, line)
            let target = min(used, line * DS.Size.promptMaxLines).rounded(.up)
            textView.enclosingScrollView?.verticalScrollElasticity = used > target ? .automatic : .none
            guard abs(parent.height - target) > 0.5 else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.height = target
            }
        }
    }
}
