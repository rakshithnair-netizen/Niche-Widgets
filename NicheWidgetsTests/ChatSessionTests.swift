import Darwin
import Foundation
import Testing
@testable import Niche_Widgets

@MainActor
struct ChatSessionTests {
    private static func ndjson(_ reply: String) -> [Data] {
        let middle = reply.index(reply.startIndex, offsetBy: reply.count / 2)
        let parts = [String(reply[..<middle]), String(reply[middle...])]
        var chunks = parts.compactMap { part -> Data? in
            let line: [String: Any] = ["message": ["role": "assistant", "content": part], "done": false]
            guard var data = try? JSONSerialization.data(withJSONObject: line) else { return nil }
            data.append(0x0A)
            return data
        }
        chunks.append(Data("{\"done\":true}\n".utf8))
        return chunks
    }

    private func makeSession(reply: String = ResponseParserTests.validReply, tags: String = "{\"models\":[{\"name\":\"qwen3:4b\"}]}") -> ChatSession {
        let host = "session-\(UUID().uuidString.lowercased()).test"
        let chunks = Self.ndjson(reply)
        let tagData = Data(tags.utf8)
        MockURLProtocol.register(host: host) { request in
            request.url?.path() == "/api/tags" ? .response(status: 200, chunks: [tagData]) : .response(status: 200, chunks: chunks)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let url = URL(string: "http://\(host)") ?? OllamaClient.defaultBaseURL
        let client = OllamaClient(baseURL: url, session: URLSession(configuration: configuration))
        let defaults = UserDefaults(suiteName: host) ?? .standard
        return ChatSession(settings: LocalAISettings(defaults: defaults), client: client)
    }

    private func waitForIdle(_ session: ChatSession) async throws {
        for _ in 0..<500 where session.isGenerating {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!session.isGenerating)
    }

    private static func physicalFootprint() -> Int64 {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? Int64(usage.ri_phys_footprint) : 0
    }

    @Test func sendProducesSixOptions() async throws {
        let session = makeSession()
        session.useExample(ChatSession.examplePrompts[0])
        #expect(session.draft == "leopard print cherry aesthetic")
        session.send()
        #expect(session.isGenerating)
        #expect(session.draft.isEmpty)
        try await waitForIdle(session)
        #expect(session.messages.count == 2)
        #expect(session.messages.last?.state == .complete)
        #expect(session.displayed?.result.options.count == 6)
        #expect(session.health == .ready)
    }

    @Test func missingModelBecomesFriendlyFailure() async throws {
        let session = makeSession(tags: "{\"models\":[]}")
        session.draft = "pastel cloud sky"
        session.send()
        try await waitForIdle(session)
        #expect(session.health == .modelMissing("qwen3:4b"))
        #expect(session.messages.last?.state == .failed(.ollama(.modelMissing("qwen3:4b"))))
        #expect(session.displayed == nil)
    }

    @Test func malformedReplyIsRetriedThenReported() async throws {
        let session = makeSession(reply: "{\"aesthetic\": \"broken\", \"options\": [")
        session.draft = "dark academia desk setup"
        session.send()
        try await waitForIdle(session)
        #expect(session.messages.last?.state == .failed(.parse(.malformed)))
    }

    @Test func newChatClearsEverything() async throws {
        let session = makeSession()
        session.draft = "pastel cloud sky"
        session.send()
        try await waitForIdle(session)
        session.newChat()
        #expect(session.messages.isEmpty)
        #expect(session.displayed == nil)
        #expect(!session.isGenerating)
    }

    @Test func twentyPromptsKeepMemoryFlat() async throws {
        let session = makeSession()
        for _ in 0..<3 {
            session.draft = "warm up"
            session.send()
            try await waitForIdle(session)
        }
        session.newChat()
        let before = Self.physicalFootprint()
        for index in 0..<20 {
            session.draft = ChatSession.examplePrompts[index % 3]
            session.send()
            try await waitForIdle(session)
        }
        #expect(session.messages.count == 40)
        session.newChat()
        let growth = Self.physicalFootprint() - before
        #expect(growth < 8 * 1024 * 1024)
    }
}
