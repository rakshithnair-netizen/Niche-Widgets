import Foundation
import Testing
@testable import Niche_Widgets

struct WidgetStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "NicheWidgetsTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func jsonFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    }

    @Test func createWritesOneFilePerWidget() async throws {
        let store = WidgetStore(directory: directory)
        try await store.loadAll()
        let samples = SampleWidgets.make()
        for model in samples {
            try await store.create(model)
        }
        #expect(try jsonFiles().count == samples.count)
        let reloaded = try await WidgetStore(directory: directory).loadAll()
        #expect(reloaded == samples)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func updatePersistsAndBumpsModifiedDate() async throws {
        let store = WidgetStore(directory: directory)
        var model = try await store.create(WidgetModel(name: "Before", createdAt: .distantPast, modifiedAt: .distantPast))
        model.name = "After"
        let updated = try await store.update(model)
        #expect(updated.name == "After")
        #expect(updated.modifiedAt > .distantPast)
        let reloaded = try await WidgetStore(directory: directory).loadAll()
        #expect(reloaded.map(\.name) == ["After"])
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func updateUnknownWidgetThrows() async throws {
        let store = WidgetStore(directory: directory)
        let stray = WidgetModel()
        await #expect(throws: WidgetStoreError.notFound(stray.id)) {
            try await store.update(stray)
        }
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func deleteRemovesFile() async throws {
        let store = WidgetStore(directory: directory)
        let keep = try await store.create(WidgetModel(name: "Keep"))
        let drop = try await store.create(WidgetModel(name: "Drop"))
        try await store.delete(id: drop.id)
        #expect(await store.list().map(\.id) == [keep.id])
        #expect(try jsonFiles().count == 1)
        await #expect(throws: WidgetStoreError.notFound(drop.id)) {
            try await store.delete(id: drop.id)
        }
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func duplicateCreatesIndependentCopy() async throws {
        let store = WidgetStore(directory: directory)
        var original = SampleWidgets.make()[0]
        original.placement = WidgetPlacement(x: 10, y: 20, displayID: 3)
        try await store.create(original)
        let copy = try await store.duplicate(id: original.id)
        #expect(copy.id != original.id)
        #expect(copy.name == original.name + " Copy")
        #expect(copy.placement == WidgetPlacement())
        #expect(copy.textLayers.map(\.content) == original.textLayers.map(\.content))
        #expect(Set(copy.textLayers.map(\.id)).isDisjoint(with: original.textLayers.map(\.id)))
        #expect(copy.background == original.background)
        #expect(await store.list().count == 2)
        #expect(try jsonFiles().count == 2)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func changesPublishEveryMutation() async throws {
        let store = WidgetStore(directory: directory)
        let stream = await store.changes()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.count == 0)
        let model = try await store.create(WidgetModel(name: "One"))
        #expect(await iterator.next()?.count == 1)
        try await store.duplicate(id: model.id)
        #expect(await iterator.next()?.count == 2)
        try await store.delete(id: model.id)
        #expect(await iterator.next()?.count == 1)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func corruptFilesAreSkipped() async throws {
        let store = WidgetStore(directory: directory)
        try await store.create(WidgetModel(name: "Good"))
        try Data("not json".utf8).write(to: directory.appending(path: "broken.json"))
        let list = try await WidgetStore(directory: directory).loadAll()
        #expect(list.map(\.name) == ["Good"])
        try? FileManager.default.removeItem(at: directory)
    }
}
