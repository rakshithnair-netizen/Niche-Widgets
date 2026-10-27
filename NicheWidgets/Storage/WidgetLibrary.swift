import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class WidgetLibrary {
    private(set) var widgets: [WidgetModel] = []
    private(set) var isLoaded = false
    @ObservationIgnored let store: WidgetStore
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.rakshithnair.NicheWidgets", category: "Library")

    init(store: WidgetStore = WidgetStore(directory: AppDirectories.widgets)) {
        self.store = store
    }

    func start() async {
        guard observation == nil else { return }
        do {
            try await store.loadAll()
            try await SampleLibrary.seedIfNeeded(store: store, disk: ImagePipeline.shared.disk)
        } catch {
            logger.error("Library bootstrap failed: \(error.localizedDescription, privacy: .public)")
        }
        let store = store
        observation = Task { [weak self] in
            for await list in await store.changes() {
                self?.widgets = list
                self?.isLoaded = true
            }
        }
    }

    func firstWidget(shaped shape: WidgetShape) -> WidgetModel? {
        widgets.first { $0.shape == shape }
    }
}
