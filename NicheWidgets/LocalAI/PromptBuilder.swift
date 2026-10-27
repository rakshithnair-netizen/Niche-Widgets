import Foundation

struct PromptBuilder: Sendable {
    static let historyLimit = 6

    struct Prompt: Sendable, Equatable {
        var system: String
        var user: String
        var messages: [OllamaMessage]
    }

    func build(text: String, palette: [String], history: [OllamaMessage] = []) -> Prompt {
        let system = Self.systemPrompt
        let user = userMessage(text: text, palette: palette)
        let trimmedHistory = Array(history.filter { $0.role != .system }.suffix(Self.historyLimit))
        let messages = [OllamaMessage(role: .system, content: system)] + trimmedHistory + [OllamaMessage(role: .user, content: user)]
        return Prompt(system: system, user: user, messages: messages)
    }

    func chatRequest(for prompt: Prompt, model: String, keepAlive: Int) -> OllamaChatRequest {
        OllamaChatRequest(
            model: model,
            messages: prompt.messages,
            stream: true,
            think: false,
            format: WidgetDesignSchema.reply,
            keepAlive: keepAlive,
            options: ["temperature": 0.7, "top_p": 0.9, "num_ctx": 8192, "num_predict": 4096]
        )
    }

    func userMessage(text: String, palette: [String]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []
        if trimmed.isEmpty {
            lines.append("Design widgets that match the attached theme images.")
        } else {
            lines.append("Aesthetic: \(trimmed)")
        }
        if !palette.isEmpty {
            lines.append("Palette extracted from the attached images, most dominant first: \(palette.joined(separator: ", ")). Build every option from these colors.")
        }
        lines.append("/no_think")
        return lines.joined(separator: "\n")
    }

    static var schemaText: String {
        WidgetDesignSchema.reply.compactString()
    }

    static var sizeText: String {
        WidgetDesignSchema.sizePresets.compactMap { preset in
            preset.dimensions.map { "\(preset.rawValue) \(Int($0.width))x\(Int($0.height))" }
        }.joined(separator: ", ")
    }

    static var systemPrompt: String {
        let s = WidgetDesignSchema.self
        return """
        You are a desktop widget designer. Turn the user's aesthetic into a cohesive set of macOS desktop widget designs.
        Reply with strict JSON only, no prose, no code fences, matching this JSON schema:
        \(schemaText)

        Shape of the reply: {"aesthetic": string, "searchTerms": [\(s.searchTermRange.lowerBound) to \(s.searchTermRange.upperBound) strings], "options": [\(s.optionCount) widget definitions]}.

        Rules:
        - aesthetic: one evocative sentence naming the mood, materials and colors, under \(s.maxAestheticLength) characters.
        - searchTerms: \(s.searchTermRange.lowerBound) to \(s.searchTermRange.upperBound) short Pinterest search phrases for background images in this aesthetic.
        - options: exactly \(s.optionCount). Use each shape exactly once: \(s.shapes.map(\.rawValue).joined(separator: ", ")).
        - sizePreset: one of \(sizeText). Use at least three different presets across the options.
        - name: a short evocative widget name, at most \(s.maxNameLength) characters.
        - background.kind is solid or linearGradient. Colors are #RRGGBB hex. gradient.colors has \(s.gradientColorRange.lowerBound) to \(s.gradientColorRange.upperBound) colors, gradient.angle is \(Int(s.gradientAngle.lowerBound)) to \(Int(s.gradientAngle.upperBound)) degrees.
        - overlay is a darkening scrim for legibility: opacity \(s.overlayOpacity.lowerBound) to \(s.overlayOpacity.upperBound), extent \(s.overlayExtent.lowerBound) to \(s.overlayExtent.upperBound), direction top, bottom, leading or trailing.
        - glass: tintOpacity \(s.tintOpacity.lowerBound) to \(s.tintOpacity.upperBound), rimHighlightOpacity \(s.rimOpacity.lowerBound) to \(s.rimOpacity.upperBound).
        - textLayers: 0 to \(s.maxTextLayers) layers. content is short widget text such as a time, date, temperature, label or tiny quote, at most \(s.maxTextLength) characters. size \(Int(s.textSize.lowerBound)) to \(Int(s.textSize.upperBound)). x and y are the anchor position as fractions \(s.textPosition.lowerBound) to \(s.textPosition.upperBound) of the widget width and height. fontName is one of \(WidgetFonts.families.joined(separator: ", ")).
        - Pick one palette of 4 to 6 clearly distinct colors for the aesthetic and use it across every option so the set feels cohesive. Gradient colors must be visibly different, for example a deep shade into a light accent. Vary which palette colors lead each option so no two options look alike, and include at least one dark option.
        - Keep text readable with strong contrast against the background. The main text of a widget is large, 28 to 56, and secondary text is 14 to 22.
        - Give every option different content, such as a clock, date, weather, battery, music, calendar or a tiny quote. Vary layouts: some text heavy, some minimal, at least one with no text.
        - Write compact JSON on a single line.
        /no_think
        """
    }
}
