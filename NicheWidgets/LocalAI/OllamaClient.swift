import Foundation

enum OllamaError: Error, Equatable, Sendable {
    case serverNotRunning
    case modelMissing(String)
    case timeout
    case badResponse(String)
    case cancelled
}

enum OllamaHealth: Equatable, Sendable {
    case ready
    case serverNotRunning
    case modelMissing(String)
}

struct OllamaMessage: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system, user, assistant
    }

    var role: Role
    var content: String
}

struct OllamaChatRequest: Sendable {
    var model: String
    var messages: [OllamaMessage]
    var stream = true
    var think = false
    var format: JSONValue? = nil
    var keepAlive: Int
    var options: JSONValue? = nil

    var json: JSONValue {
        var pairs: [(String, JSONValue)] = [
            ("model", .string(model)),
            ("messages", .array(messages.map { ["role": .string($0.role.rawValue), "content": .string($0.content)] })),
            ("stream", .bool(stream)),
            ("think", .bool(think)),
            ("keep_alive", .number(Double(keepAlive)))
        ]
        if let format { pairs.append(("format", format)) }
        if let options { pairs.append(("options", options)) }
        return .object(pairs)
    }
}

struct OllamaTimeouts: Sendable {
    var health: TimeInterval = 3
    var idle: TimeInterval = 90
    var total: TimeInterval = 300
}

actor OllamaClient {
    static let defaultBaseURL = URL(string: "http://127.0.0.1:11434") ?? URL(fileURLWithPath: "/")

    private struct ChatChunk: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message?
        var done: Bool?
        var error: String?
    }

    private struct TagList: Decodable {
        struct Model: Decodable {
            var name: String
            var model: String?
        }

        var models: [Model]
    }

    private struct ErrorBody: Decodable {
        var error: String
    }

    nonisolated let baseURL: URL
    nonisolated let session: URLSession
    nonisolated let timeouts: OllamaTimeouts

    init(baseURL: URL = OllamaClient.defaultBaseURL, session: URLSession? = nil, timeouts: OllamaTimeouts = OllamaTimeouts()) {
        self.baseURL = baseURL
        self.timeouts = timeouts
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeouts.idle
            configuration.timeoutIntervalForResource = timeouts.total
            configuration.waitsForConnectivity = false
            configuration.httpMaximumConnectionsPerHost = 2
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    static func normalizedModelName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains(":") ? trimmed : trimmed + ":latest"
    }

    func health(model: String) async -> OllamaHealth {
        var request = URLRequest(url: baseURL.appending(path: "api/tags"))
        request.timeoutInterval = timeouts.health
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let list = try? JSONDecoder().decode(TagList.self, from: data)
            else { return .serverNotRunning }
            let wanted = Self.normalizedModelName(model)
            let installed = list.models.flatMap { [$0.name, $0.model ?? $0.name] }.map(Self.normalizedModelName)
            return installed.contains(wanted) ? .ready : .modelMissing(model)
        } catch {
            return .serverNotRunning
        }
    }

    nonisolated func chat(_ chatRequest: OllamaChatRequest) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self, throwing: Error.self)
        let task = Task { [session, baseURL, timeouts] in
            do {
                let request = Self.makeChatRequest(chatRequest, baseURL: baseURL, timeout: timeouts.idle)
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { throw OllamaError.badResponse("No HTTP response") }
                guard http.statusCode == 200 else {
                    var body = Data()
                    for try await byte in bytes {
                        body.append(byte)
                        if body.count > 4096 { break }
                    }
                    throw Self.httpError(status: http.statusCode, body: body, model: chatRequest.model)
                }
                var finished = false
                for try await line in bytes.lines {
                    try Task.checkCancellation()
                    if let token = try Self.parseLine(line, model: chatRequest.model, finished: &finished), !token.isEmpty {
                        continuation.yield(token)
                    }
                    if finished { break }
                }
                guard finished else { throw OllamaError.badResponse("The stream ended early") }
                continuation.finish()
            } catch {
                continuation.finish(throwing: Self.map(error))
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func complete(_ chatRequest: OllamaChatRequest) async throws -> String {
        var text = ""
        for try await token in chat(chatRequest) {
            text += token
        }
        if Task.isCancelled { throw OllamaError.cancelled }
        return text
    }

    func unload(model: String) async {
        let request = OllamaChatRequest(model: model, messages: [], stream: false, keepAlive: 0)
        let urlRequest = Self.makeChatRequest(request, baseURL: baseURL, timeout: timeouts.health)
        _ = try? await session.data(for: urlRequest)
    }

    func ping(model: String, keepAlive: Int) async throws -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        switch await health(model: model) {
        case .serverNotRunning: throw OllamaError.serverNotRunning
        case .modelMissing(let name): throw OllamaError.modelMissing(name)
        case .ready: break
        }
        let request = OllamaChatRequest(
            model: model,
            messages: [OllamaMessage(role: .user, content: "Reply with OK.")],
            keepAlive: keepAlive,
            options: ["num_predict": 4]
        )
        _ = try await complete(request)
        return clock.now - start
    }

    static func parseLine(_ line: String, model: String, finished: inout Bool) throws -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let chunk = try? JSONDecoder().decode(ChatChunk.self, from: Data(trimmed.utf8)) else {
            throw OllamaError.badResponse("Unreadable stream line")
        }
        if let error = chunk.error {
            throw messageError(error, model: model)
        }
        finished = chunk.done ?? false
        guard let content = chunk.message?.content, !content.isEmpty else { return finished ? "" : nil }
        return content
    }

    private static func makeChatRequest(_ chatRequest: OllamaChatRequest, baseURL: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        request.httpBody = chatRequest.json.data()
        return request
    }

    private static func httpError(status: Int, body: Data, model: String) -> OllamaError {
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.error ?? String(decoding: body, as: UTF8.self)
        if status == 404 { return .modelMissing(model) }
        return messageError(message.isEmpty ? "HTTP \(status)" : message, model: model)
    }

    private static func messageError(_ message: String, model: String) -> OllamaError {
        let lower = message.lowercased()
        if lower.contains("not found") && lower.contains("model") { return .modelMissing(model) }
        return .badResponse(message)
    }

    static func map(_ error: Error) -> OllamaError {
        if let error = error as? OllamaError { return error }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed, .resourceUnavailable:
                return .serverNotRunning
            default: return .badResponse(error.localizedDescription)
            }
        }
        if Task.isCancelled { return .cancelled }
        return .badResponse(error.localizedDescription)
    }
}
