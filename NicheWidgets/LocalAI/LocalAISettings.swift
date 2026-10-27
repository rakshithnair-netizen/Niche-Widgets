import Foundation
import Observation

enum ModelKeepAlive: Int, CaseIterable, Identifiable, Sendable {
    case unloadNow = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var seconds: Int { rawValue }

    var title: String {
        switch self {
        case .unloadNow: "Unload"
        case .oneMinute: "1 min"
        case .fiveMinutes: "5 min"
        }
    }
}

@MainActor
@Observable
final class LocalAISettings {
    static let defaultModel = "qwen3:4b"
    private static let modelKey = "localAI.model"
    private static let keepAliveKey = "localAI.keepAlive"

    @ObservationIgnored private let defaults: UserDefaults

    var modelName: String {
        didSet { defaults.set(modelName, forKey: Self.modelKey) }
    }

    var keepAlive: ModelKeepAlive {
        didSet { defaults.set(keepAlive.rawValue, forKey: Self.keepAliveKey) }
    }

    var resolvedModel: String {
        let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultModel : trimmed
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        modelName = defaults.string(forKey: Self.modelKey) ?? Self.defaultModel
        if defaults.object(forKey: Self.keepAliveKey) != nil {
            keepAlive = ModelKeepAlive(rawValue: defaults.integer(forKey: Self.keepAliveKey)) ?? .oneMinute
        } else {
            keepAlive = .oneMinute
        }
    }
}
