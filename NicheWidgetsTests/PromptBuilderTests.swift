import Foundation
import Testing
@testable import Niche_Widgets

struct PromptBuilderTests {
    @Test func systemPromptIncludesSchemaAndRanges() {
        let prompt = PromptBuilder().build(text: "pastel cloud sky", palette: [])
        #expect(prompt.system.contains(PromptBuilder.schemaText))
        for shape in WidgetShape.allCases {
            #expect(prompt.system.contains(shape.rawValue))
        }
        for preset in WidgetDesignSchema.sizePresets {
            #expect(prompt.system.contains(preset.rawValue))
        }
        #expect(prompt.system.contains("338x158"))
        #expect(prompt.system.contains("\"aesthetic\""))
        #expect(prompt.system.contains("searchTerms"))
        #expect(prompt.system.contains("/no_think"))
        #expect(prompt.messages.first == OllamaMessage(role: .system, content: prompt.system))
        #expect(prompt.messages.last == OllamaMessage(role: .user, content: prompt.user))
        #expect(prompt.user.contains("pastel cloud sky"))
    }

    @Test func userMessageIncludesPalette() {
        let palette = ["#7A1F2B", "#E8B04A", "#2B1A12", "#F5E6D3", "#C23B3B"]
        let prompt = PromptBuilder().build(text: "", palette: palette)
        for hex in palette {
            #expect(prompt.user.contains(hex))
        }
        #expect(prompt.user.contains("attached"))
    }

    @Test func historyIsCappedAtSixMessages() {
        let history = (0..<10).map { OllamaMessage(role: $0.isMultiple(of: 2) ? .user : .assistant, content: "turn \($0)") }
        let prompt = PromptBuilder().build(text: "next", palette: [], history: history)
        #expect(prompt.messages.count == 1 + PromptBuilder.historyLimit + 1)
        #expect(prompt.messages[1].content == "turn 4")
        #expect(prompt.messages[prompt.messages.count - 2].content == "turn 9")
    }

    @Test func chatRequestUsesStructuredOutputAndDisablesThinking() throws {
        let builder = PromptBuilder()
        let request = builder.chatRequest(for: builder.build(text: "dark academia", palette: []), model: "qwen3:4b", keepAlive: 60)
        #expect(request.format == WidgetDesignSchema.reply)
        #expect(request.think == false)
        #expect(request.stream)
        let json = try #require(try JSONSerialization.jsonObject(with: request.json.data()) as? [String: Any])
        #expect(json["keep_alive"] as? Int == 60)
        #expect(json["think"] as? Bool == false)
        #expect(json["model"] as? String == "qwen3:4b")
        let format = try #require(json["format"] as? [String: Any])
        let properties = try #require(format["properties"] as? [String: Any])
        let options = try #require(properties["options"] as? [String: Any])
        #expect(options["minItems"] as? Int == 6)
        #expect(options["maxItems"] as? Int == 6)
    }

    @Test func schemaTextIsStable() {
        #expect(PromptBuilder.schemaText == PromptBuilder.schemaText)
        #expect(PromptBuilder.systemPrompt == PromptBuilder.systemPrompt)
    }

    @Test func schemaPreservesPropertyOrder() {
        let text = PromptBuilder.schemaText
        let aesthetic = text.range(of: "\"aesthetic\"")
        let terms = text.range(of: "\"searchTerms\"")
        let options = text.range(of: "\"options\"")
        #expect(aesthetic != nil && terms != nil && options != nil)
        if let aesthetic, let terms, let options {
            #expect(aesthetic.lowerBound < terms.lowerBound)
            #expect(terms.lowerBound < options.lowerBound)
        }
    }
}
