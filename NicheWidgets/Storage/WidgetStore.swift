import Foundation

enum WidgetStoreError: Error, Equatable {
    case notFound(UUID)
}

actor WidgetStore {
    private let directory: URL
    private let encoder = WidgetModel.makeEncoder()
    private let decoder = WidgetModel.makeDecoder()
    private var widgets: [UUID: WidgetModel] = [:]
    private var subscribers: [UUID: AsyncStream<[WidgetModel]>.Continuation] = [:]

    init(directory: URL) {
        self.directory = directory
    }

    @discardableResult
    func loadAll() throws -> [WidgetModel] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var loaded: [UUID: WidgetModel] = [:]
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let model = try? decoder.decode(WidgetModel.self, from: data)
            else { continue }
            loaded[model.id] = model
        }
        widgets = loaded
        publish()
        return list()
    }

    func list() -> [WidgetModel] {
        widgets.values.sorted {
            $0.createdAt == $1.createdAt ? $0.name < $1.name : $0.createdAt < $1.createdAt
        }
    }

    func widget(id: UUID) -> WidgetModel? {
        widgets[id]
    }

    @discardableResult
    func create(_ model: WidgetModel) throws -> WidgetModel {
        var created = model
        created.schemaVersion = WidgetModel.currentSchemaVersion
        try write(created)
        widgets[created.id] = created
        publish()
        return created
    }

    @discardableResult
    func update(_ model: WidgetModel) throws -> WidgetModel {
        guard widgets[model.id] != nil else { throw WidgetStoreError.notFound(model.id) }
        var updated = model
        updated.schemaVersion = WidgetModel.currentSchemaVersion
        updated.modifiedAt = Date()
        try write(updated)
        widgets[updated.id] = updated
        publish()
        return updated
    }

    func delete(id: UUID) throws {
        guard widgets[id] != nil else { throw WidgetStoreError.notFound(id) }
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        widgets[id] = nil
        publish()
    }

    @discardableResult
    func duplicate(id: UUID) throws -> WidgetModel {
        guard let original = widgets[id] else { throw WidgetStoreError.notFound(id) }
        let now = Date()
        var copy = original
        copy.id = UUID()
        copy.name = original.name + " Copy"
        copy.createdAt = now
        copy.modifiedAt = now
        copy.placement = WidgetPlacement()
        copy.textLayers = original.textLayers.map { layer in
            var fresh = layer
            fresh.id = UUID()
            return fresh
        }
        return try create(copy)
    }

    func changes() -> AsyncStream<[WidgetModel]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [WidgetModel].self, bufferingPolicy: .bufferingNewest(1))
        let token = UUID()
        subscribers[token] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(token) }
        }
        continuation.yield(list())
        return stream
    }

    private func unsubscribe(_ token: UUID) {
        subscribers[token] = nil
    }

    private func publish() {
        let snapshot = list()
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: id.uuidString + ".json", directoryHint: .notDirectory)
    }

    private func write(_ model: WidgetModel) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(model)
        try data.write(to: fileURL(for: model.id), options: .atomic)
    }
}
