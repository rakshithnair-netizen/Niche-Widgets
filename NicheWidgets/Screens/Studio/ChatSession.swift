import Foundation
import Observation

enum ModelHealth: Equatable, Sendable {
    case unknown
    case checking
    case ready
    case serverNotRunning
    case modelMissing(String)

    var needsAttention: Bool {
        switch self {
        case .serverNotRunning, .modelMissing: true
        default: false
        }
    }
}

@MainActor
@Observable
final class ChatMessage: Identifiable {
    enum Role: Equatable { case user, assistant }

    enum State: Equatable {
        case typing
        case working(GenerationPhase)
        case complete
        case stopped
        case failed(DesignError)
    }

    let id = UUID()
    let role: Role
    let text: String
    let attachments: [ImageAttachment]
    let palette: [String]
    var state: State
    var result: DesignResult?

    init(role: Role, text: String, attachments: [ImageAttachment] = [], palette: [String] = [], state: State = .complete) {
        self.role = role
        self.text = text
        self.attachments = attachments
        self.palette = palette
        self.state = state
    }

    var isPending: Bool {
        switch state {
        case .typing, .working: true
        default: false
        }
    }
}

struct DisplayedOptions: Equatable {
    let id: UUID
    let result: DesignResult
}

@MainActor
@Observable
final class ChatSession {
    static let examplePrompts = ["leopard print cherry aesthetic", "dark academia desk setup", "pastel cloud sky"]

    private(set) var messages: [ChatMessage] = []
    private(set) var health = ModelHealth.unknown
    private(set) var displayed: DisplayedOptions?
    private(set) var isGenerating = false
    var selectedOptionID: UUID?
    var draft = ""
    var attachments: [ImageAttachment] = []
    var focusRequest = 0

    @ObservationIgnored let settings: LocalAISettings
    @ObservationIgnored let client: OllamaClient
    @ObservationIgnored private var generation: Task<Void, Never>?
    @ObservationIgnored private var generationID: UUID?
    @ObservationIgnored private var attachmentLoads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private let builder = PromptBuilder()

    init(settings: LocalAISettings, client: OllamaClient = OllamaClient()) {
        self.settings = settings
        self.client = client
    }

    var canSend: Bool {
        !isGenerating && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty)
    }

    func useExample(_ prompt: String) {
        draft = prompt
        focusRequest += 1
    }

    func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let palette = ImageAttachmentLoader.combinedPalette(attachments)
        let user = ChatMessage(role: .user, text: text, attachments: attachments, palette: palette)
        let assistant = ChatMessage(role: .assistant, text: "", state: .typing)
        let history = history(before: messages.count)
        messages.append(user)
        messages.append(assistant)
        draft = ""
        attachments = []
        start(assistant: assistant, user: user, history: history)
    }

    func retry(_ assistant: ChatMessage) {
        guard !isGenerating, let index = messages.firstIndex(where: { $0.id == assistant.id }), index > 0 else { return }
        let user = messages[index - 1]
        guard user.role == .user else { return }
        assistant.result = nil
        assistant.state = .typing
        start(assistant: assistant, user: user, history: history(before: index - 1))
    }

    func stop() {
        generation?.cancel()
    }

    func newChat() {
        generation?.cancel()
        generation = nil
        generationID = nil
        for load in attachmentLoads.values { load.cancel() }
        attachmentLoads = [:]
        messages = []
        displayed = nil
        selectedOptionID = nil
        draft = ""
        attachments = []
        isGenerating = false
        let client = client
        let model = settings.resolvedModel
        Task { await client.unload(model: model) }
    }

    func refreshHealth() async {
        if !health.needsAttention { health = .checking }
        health = Self.health(from: await client.health(model: settings.resolvedModel))
    }

    func pollHealthWhileUnavailable() async {
        while health.needsAttention, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(DS.Motion.healthPollInterval))
            guard !Task.isCancelled else { return }
            await refreshHealth()
        }
    }

    func attach(urls: [URL]) {
        for url in urls where ImageAttachmentLoader.isImage(url) {
            load { try await ImageAttachmentLoader.load(url: url) }
        }
    }

    func attach(data: Data, name: String) {
        load { try await ImageAttachmentLoader.load(data: data, name: name) }
    }

    func removeAttachment(_ attachment: ImageAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    private func load(_ work: @escaping @Sendable () async throws -> ImageAttachment) {
        guard attachments.count + attachmentLoads.count < ImageAttachmentLoader.maxAttachments else { return }
        let token = UUID()
        attachmentLoads[token] = Task { [weak self] in
            let attachment = try? await work()
            guard let self, !Task.isCancelled else { return }
            self.attachmentLoads[token] = nil
            if let attachment, self.attachments.count < ImageAttachmentLoader.maxAttachments {
                self.attachments.append(attachment)
            }
        }
    }

    private func start(assistant: ChatMessage, user: ChatMessage, history: [OllamaMessage]) {
        isGenerating = true
        selectedOptionID = nil
        let request = DesignRequest(
            text: user.text,
            palette: user.palette,
            history: history,
            model: settings.resolvedModel,
            keepAlive: settings.keepAlive.seconds
        )
        let generator = DesignGenerator(client: client, builder: builder)
        let id = UUID()
        generationID = id
        generation = Task { [weak self, weak assistant] in
            await self?.run(generator, request: request, assistant: assistant, id: id)
        }
    }

    private func run(_ generator: DesignGenerator, request: DesignRequest, assistant: ChatMessage?, id: UUID) async {
        defer {
            if generationID == id {
                isGenerating = false
                generation = nil
                generationID = nil
            }
        }
        guard let assistant else { return }
        let status = Self.health(from: await client.health(model: request.model))
        health = status
        guard !Task.isCancelled else {
            assistant.state = .stopped
            return
        }
        switch status {
        case .serverNotRunning:
            assistant.state = .failed(.ollama(.serverNotRunning))
            return
        case .modelMissing(let name):
            assistant.state = .failed(.ollama(.modelMissing(name)))
            return
        default:
            break
        }
        do {
            let output = try await generator.generate(request) { [weak assistant] phase in
                guard let assistant, assistant.state != .working(phase) else { return }
                assistant.state = .working(phase)
            }
            assistant.result = output.result
            assistant.state = .complete
            if generationID == id {
                displayed = DisplayedOptions(id: assistant.id, result: output.result)
            }
        } catch {
            let failure = DesignError.wrap(error)
            switch failure {
            case .ollama(.cancelled):
                assistant.state = .stopped
            case .ollama(.serverNotRunning):
                health = .serverNotRunning
                assistant.state = .failed(failure)
            case .ollama(.modelMissing(let name)):
                health = .modelMissing(name)
                assistant.state = .failed(failure)
            default:
                assistant.state = .failed(failure)
            }
        }
    }

    private func history(before index: Int) -> [OllamaMessage] {
        var turns: [OllamaMessage] = []
        var pendingUser: ChatMessage?
        for message in messages.prefix(index) {
            switch message.role {
            case .user:
                pendingUser = message
            case .assistant:
                guard let user = pendingUser, let result = message.result else { continue }
                turns.append(OllamaMessage(role: .user, content: builder.userMessage(text: user.text, palette: user.palette)))
                turns.append(OllamaMessage(role: .assistant, content: Self.summary(of: result)))
                pendingUser = nil
            }
        }
        return Array(turns.suffix(PromptBuilder.historyLimit))
    }

    static func summary(of result: DesignResult) -> String {
        let options: [JSONValue] = result.options.map { option in
            [
                "name": .string(option.name),
                "shape": .string(option.shape.rawValue),
                "sizePreset": .string(option.size.preset.rawValue),
                "colors": .array(([option.background.color] + option.background.gradient.colors).map(JSONValue.string))
            ]
        }
        let summary: JSONValue = [
            "aesthetic": .string(result.aesthetic),
            "searchTerms": .array(result.searchTerms.map(JSONValue.string)),
            "options": .array(options)
        ]
        return summary.compactString()
    }

    private static func health(from status: OllamaHealth) -> ModelHealth {
        switch status {
        case .ready: .ready
        case .serverNotRunning: .serverNotRunning
        case .modelMissing(let name): .modelMissing(name)
        }
    }
}
