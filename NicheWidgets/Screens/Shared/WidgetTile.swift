import SwiftUI

struct WidgetTile: View {
    let model: WidgetModel
    var pipeline: ImagePipeline = .shared
    @State private var image: CGImage?
    @State private var settledRequest: ImageRequest?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var request: ImageRequest? {
        model.imageRequest(scale: displayScale)
    }

    private var isLoading: Bool {
        guard let request else { return false }
        return settledRequest != request
    }

    var body: some View {
        let size = model.resolvedSize
        WidgetLayerView(model: model, image: request == nil ? nil : image)
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .overlay {
                if isLoading {
                    WidgetOutline(model)
                        .fill(DS.Palette.skeleton)
                        .shimmering()
                        .transition(.opacity)
                }
            }
            .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: isLoading)
            .task(id: request) {
                await load()
            }
            .accessibilityElement()
            .accessibilityLabel(model.name)
    }

    private func load() async {
        guard let request else {
            image = nil
            settledRequest = nil
            return
        }
        if let cached = pipeline.cachedImage(for: request) {
            image = cached
            settledRequest = request
            return
        }
        do {
            let loaded = try await pipeline.image(for: request)
            image = loaded
            settledRequest = request
        } catch is CancellationError {
            return
        } catch {
            image = nil
            settledRequest = request
        }
    }
}
