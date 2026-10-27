import Foundation
import Testing
@testable import Niche_Widgets

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case response(status: Int, chunks: [Data])
        case failure(URLError.Code)
        case hang
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: @Sendable (URLRequest) -> Reply] = [:]
    nonisolated(unsafe) private static var stopped: Set<String> = []

    static func register(host: String, handler: @escaping @Sendable (URLRequest) -> Reply) {
        lock.withLock { handlers[host] = handler }
    }

    static func wasStopped(host: String) -> Bool {
        lock.withLock { stopped.contains(host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host() ?? ""
        guard let handler = Self.lock.withLock({ Self.handlers[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        switch handler(request) {
        case .response(let status, let chunks):
            guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/x-ndjson"]) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        }
    }

    override func stopLoading() {
        let host = request.url?.host() ?? ""
        Self.lock.withLock { _ = Self.stopped.insert(host) }
    }
}

struct OllamaClientTests {
    private func makeClient(_ handler: @escaping @Sendable (URLRequest) -> MockURLProtocol.Reply) -> (OllamaClient, String) {
        let host = "mock-\(UUID().uuidString.lowercased()).test"
        MockURLProtocol.register(host: host, handler: handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let url = URL(string: "http://\(host):11434") ?? OllamaClient.defaultBaseURL
        return (OllamaClient(baseURL: url, session: session), host)
    }

    private func request(_ model: String = "qwen3:4b") -> OllamaChatRequest {
        OllamaChatRequest(model: model, messages: [OllamaMessage(role: .user, content: "hi")], keepAlive: 0)
    }

    private func line(_ content: String, done: Bool = false) -> String {
        let escaped = content.replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"model\":\"qwen3:4b\",\"message\":{\"role\":\"assistant\",\"content\":\"\(escaped)\"},\"done\":\(done)}\n"
    }

    private func collect(_ client: OllamaClient, _ request: OllamaChatRequest) async -> Result<[String], OllamaError> {
        var tokens: [String] = []
        do {
            for try await token in client.chat(request) {
                tokens.append(token)
            }
            return .success(tokens)
        } catch {
            return .failure(OllamaClient.map(error))
        }
    }

    @Test func streamingParsesNewlineDelimitedJSONAcrossChunks() async throws {
        let body = line("{\"aes") + line("thetic\": ") + line("\"soft\"}") + line("", done: true)
        let bytes = Array(body.utf8)
        let chunks = stride(from: 0, to: bytes.count, by: 17).map { Data(bytes[$0..<min($0 + 17, bytes.count)]) }
        let (client, _) = makeClient { request in
            #expect(request.url?.path() == "/api/chat")
            return .response(status: 200, chunks: chunks)
        }
        let result = await collect(client, request())
        #expect(try result.get() == ["{\"aes", "thetic\": ", "\"soft\"}"])
        #expect(try await client.complete(request()) == "{\"aesthetic\": \"soft\"}")
    }

    @Test func requestBodyCarriesKeepAliveAndThinkFlag() async throws {
        let (client, _) = makeClient { request in
            let body = request.httpBodyStream.map(Self.read) ?? request.httpBody ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            let ok = json?["keep_alive"] as? Int == 0 && json?["think"] as? Bool == false && json?["stream"] as? Bool == true
            return .response(status: ok ? 200 : 400, chunks: [Data(("{\"done\":true}\n").utf8)])
        }
        _ = try await client.complete(request())
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    @Test func serverDownIsReported() async {
        let (client, _) = makeClient { _ in .failure(.cannotConnectToHost) }
        #expect(await client.health(model: "qwen3:4b") == .serverNotRunning)
        #expect(await collect(client, request()) == .failure(.serverNotRunning))
    }

    @Test func modelMissingIsReported() async {
        let tags = Data("{\"models\":[{\"name\":\"llama3:8b\",\"model\":\"llama3:8b\"},{\"name\":\"qwen3:latest\"}]}".utf8)
        let (client, _) = makeClient { request in
            if request.url?.path() == "/api/tags" {
                return .response(status: 200, chunks: [tags])
            }
            return .response(status: 404, chunks: [Data("{\"error\":\"model 'qwen3:4b' not found\"}".utf8)])
        }
        #expect(await client.health(model: "qwen3:4b") == .modelMissing("qwen3:4b"))
        #expect(await client.health(model: "llama3:8b") == .ready)
        #expect(await client.health(model: "qwen3") == .ready)
        #expect(await collect(client, request()) == .failure(.modelMissing("qwen3:4b")))
    }

    @Test func streamErrorLineIsTyped() async {
        let body = line("partial") + "{\"error\":\"model 'qwen3:4b' not found, try pulling it first\"}\n"
        let (client, _) = makeClient { _ in .response(status: 200, chunks: [Data(body.utf8)]) }
        #expect(await collect(client, request()) == .failure(.modelMissing("qwen3:4b")))
    }

    @Test func truncatedStreamIsBadResponse() async {
        let (client, _) = makeClient { _ in .response(status: 200, chunks: [Data(line("only").utf8)]) }
        guard case .failure(.badResponse) = await collect(client, request()) else {
            Issue.record("Expected badResponse")
            return
        }
    }

    @Test func timeoutIsReported() async {
        let (client, _) = makeClient { _ in .failure(.timedOut) }
        #expect(await collect(client, request()) == .failure(.timeout))
    }

    @Test func cancellationClosesTheConnection() async throws {
        let (client, host) = makeClient { _ in .hang }
        let task = Task { try await client.complete(request()) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        let result = await task.result
        #expect(throws: OllamaError.cancelled) { try result.get() }
        for _ in 0..<50 where !MockURLProtocol.wasStopped(host: host) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(MockURLProtocol.wasStopped(host: host))
    }

    @Test func errorMappingCoversEveryCase() {
        #expect(OllamaClient.map(URLError(.cannotConnectToHost)) == .serverNotRunning)
        #expect(OllamaClient.map(URLError(.timedOut)) == .timeout)
        #expect(OllamaClient.map(URLError(.cancelled)) == .cancelled)
        #expect(OllamaClient.map(CancellationError()) == .cancelled)
        #expect(OllamaClient.map(OllamaError.modelMissing("m")) == .modelMissing("m"))
    }
}
