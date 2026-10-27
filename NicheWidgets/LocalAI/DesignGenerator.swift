import Foundation

enum GenerationPhase: Equatable, Sendable {
    case thinking
    case designing(current: Int)
    case retrying
}

enum DesignError: Error, Equatable, Sendable {
    case ollama(OllamaError)
    case parse(ResponseParseError)

    static func wrap(_ error: Error) -> DesignError {
        if let error = error as? DesignError { return error }
        if let error = error as? ResponseParseError { return .parse(error) }
        return .ollama(OllamaClient.map(error))
    }
}

struct DesignRequest: Sendable {
    var text: String
    var palette: [String]
    var history: [OllamaMessage]
    var model: String
    var keepAlive: Int
}

struct DesignOutput: Sendable {
    var result: DesignResult
    var reply: String
}

struct DesignGenerator: Sendable {
    static let maxAttempts = 2
    private static let optionMarker = "\"sizePreset\""

    let client: OllamaClient
    var builder = PromptBuilder()

    @concurrent
    func generate(_ request: DesignRequest, progress: @escaping @MainActor @Sendable (GenerationPhase) -> Void) async throws -> DesignOutput {
        let prompt = builder.build(text: request.text, palette: request.palette, history: request.history)
        let chatRequest = builder.chatRequest(for: prompt, model: request.model, keepAlive: request.keepAlive)
        let parser = ResponseParser(palette: request.palette)
        var lastError = DesignError.parse(.malformed)
        for attempt in 0..<Self.maxAttempts {
            await progress(attempt == 0 ? .thinking : .retrying)
            let reply: String
            do {
                reply = try await collect(chatRequest, progress: progress)
            } catch {
                throw DesignError.wrap(error)
            }
            if Task.isCancelled { throw DesignError.ollama(.cancelled) }
            do {
                let result = try parser.parse(reply)
                return DesignOutput(result: result, reply: ResponseParser.repair(reply))
            } catch {
                lastError = .parse(error)
            }
        }
        throw lastError
    }

    private func collect(_ chatRequest: OllamaChatRequest, progress: @escaping @MainActor @Sendable (GenerationPhase) -> Void) async throws -> String {
        var text = ""
        var current = 0
        var started = false
        let markerLength = Self.optionMarker.count
        for try await token in client.chat(chatRequest) {
            text += token
            if !started {
                started = true
                await progress(.designing(current: 0))
            }
            if text.suffix(token.count + markerLength - 1).contains(Self.optionMarker) {
                current += 1
                await progress(.designing(current: min(current, WidgetDesignSchema.optionCount)))
            }
        }
        try Task.checkCancellation()
        return text
    }
}
