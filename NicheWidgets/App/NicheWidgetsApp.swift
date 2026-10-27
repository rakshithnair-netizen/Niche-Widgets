import SwiftUI

@main
struct NicheWidgetsApp: App {
    @State private var library = WidgetLibrary()

    var body: some Scene {
        Window("Niche Widgets", id: "main") {
            RootView()
                .frame(minWidth: DS.Size.windowMinWidth, minHeight: DS.Size.windowMinHeight)
                .background(WindowConfigurator())
                .containerBackground(for: .window) {
                    MatteGlassBackground()
                }
                .preferredColorScheme(.dark)
                .environment(library)
                .task {
                    guard !AppDirectories.isRunningTests else { return }
                    await library.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: DS.Size.windowDefaultWidth, height: DS.Size.windowDefaultHeight)
        .windowBackgroundDragBehavior(.enabled)
    }
}
