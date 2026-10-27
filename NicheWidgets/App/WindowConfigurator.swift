import SwiftUI
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowAccessorView {
        WindowAccessorView()
    }

    func updateNSView(_ view: WindowAccessorView, context: Context) {}
}

final class WindowAccessorView: NSView {
    private static let autosaveName = "NicheWidgetsMainWindow"

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        configure(window)
    }

    private func configure(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: DS.Size.windowMinWidth, height: DS.Size.windowMinHeight)
        if window.frameAutosaveName != Self.autosaveName {
            window.setFrameUsingName(Self.autosaveName)
            window.setFrameAutosaveName(Self.autosaveName)
        }
    }
}
