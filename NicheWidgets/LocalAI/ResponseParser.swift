import Foundation

struct DesignResult: Sendable, Equatable {
    var aesthetic: String
    var searchTerms: [String]
    var options: [WidgetModel]
    var palette: [String]
}

enum ResponseParseError: Error, Equatable, Sendable {
    case malformed
    case noUsableOptions
}

struct ResponseParser: Sendable {
    static let defaultPalette = ["#2B3040", "#6B7590", "#A9B4CC", "#E4E8F0", "#14161C"]
    static let defaultAesthetic = "Custom aesthetic"

    var palette: [String] = []
    var now: Date = Date()

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?

        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct RawReply: Decodable {
        var aesthetic: String?
        var searchTerms: [Lossy<String>]
        var options: [Lossy<RawOption>]

        enum CodingKeys: String, CodingKey {
            case aesthetic, searchTerms, options
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            aesthetic = c.optionalValue(.aesthetic)
            searchTerms = c.value(.searchTerms, or: [])
            options = c.value(.options, or: [])
        }
    }

    private struct RawOption: Decodable {
        enum InvalidOption: Error { case shape }

        var shape: WidgetShape
        var sizePreset: String?
        var hasBackground: Bool
        var model: WidgetModel

        enum CodingKeys: String, CodingKey {
            case shape, sizePreset, background
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try c.decode(String.self, forKey: .shape).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let shape = WidgetShape.allCases.first(where: { $0.rawValue.lowercased() == raw }) else { throw InvalidOption.shape }
            self.shape = shape
            sizePreset = c.optionalValue(.sizePreset)
            hasBackground = c.contains(.background)
            model = try WidgetModel(from: decoder)
        }
    }

    func parse(_ text: String) throws(ResponseParseError) -> DesignResult {
        guard let reply = Self.decode(text) ?? Self.decode(Self.repair(text)) else { throw .malformed }
        let options = reply.options.compactMap(\.value)
        guard !options.isEmpty else { throw .noUsableOptions }
        let basePalette = palette.compactMap(Self.normalizedHex)
        let fallback = basePalette.isEmpty ? Self.defaultPalette : basePalette
        let models = options.prefix(WidgetDesignSchema.optionCount).enumerated().map { index, option in
            sanitize(option, index: index, palette: fallback)
        }
        let aesthetic = Self.clip(reply.aesthetic ?? "", to: WidgetDesignSchema.maxAestheticLength)
        let resolvedAesthetic = aesthetic.isEmpty ? Self.defaultAesthetic : aesthetic
        return DesignResult(
            aesthetic: resolvedAesthetic,
            searchTerms: Self.searchTerms(reply.searchTerms.compactMap(\.value), fallback: resolvedAesthetic),
            options: models,
            palette: basePalette.isEmpty ? Self.palette(from: models) : basePalette
        )
    }

    static func repair(_ text: String) -> String {
        var cleaned = text
        while let start = cleaned.range(of: "<think>"), let end = cleaned.range(of: "</think>", range: start.upperBound..<cleaned.endIndex) {
            cleaned.removeSubrange(start.lowerBound..<end.upperBound)
        }
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        guard let first = cleaned.firstIndex(of: "{"), let last = cleaned.lastIndex(of: "}"), first < last else {
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(cleaned[first...last])
    }

    static func normalizedHex(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rgba = HexColor.parse(trimmed) else { return nil }
        return HexColor.string(RGBA(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: 1))
    }

    static func placeholderBackground(palette: [String], index: Int) -> WidgetBackground {
        let colors = palette.isEmpty ? defaultPalette : palette
        let first = colors[index % colors.count]
        let second = colors[(index + 2) % colors.count]
        return WidgetBackground(
            kind: .linearGradient,
            color: first,
            gradient: WidgetGradient(colors: first == second ? [first, colors[(index + 1) % colors.count]] : [first, second], angle: Double(120 + index * 30).truncatingRemainder(dividingBy: 360))
        )
    }

    private static func decode(_ text: String) -> RawReply? {
        guard !text.isEmpty else { return nil }
        return try? JSONDecoder().decode(RawReply.self, from: Data(text.utf8))
    }

    private static func clip(_ text: String, to length: Int) -> String {
        let collapsed = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count > length ? String(collapsed.prefix(length)).trimmingCharacters(in: .whitespaces) : collapsed
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func searchTerms(_ raw: [String], fallback: String) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []
        for term in raw {
            let cleaned = clip(term, to: WidgetDesignSchema.maxSearchTermLength)
            guard !cleaned.isEmpty, seen.insert(cleaned.lowercased()).inserted else { continue }
            terms.append(cleaned)
            if terms.count == WidgetDesignSchema.searchTermRange.upperBound { break }
        }
        return terms.isEmpty ? [fallback] : terms
    }

    private static func palette(from models: [WidgetModel]) -> [String] {
        var seen = Set<String>()
        var colors: [String] = []
        for color in models.flatMap({ [$0.background.color] + $0.background.gradient.colors }) where seen.insert(color).inserted {
            colors.append(color)
            if colors.count == 5 { break }
        }
        return colors.isEmpty ? defaultPalette : colors
    }

    private func sanitize(_ option: RawOption, index: Int, palette: [String]) -> WidgetModel {
        var model = option.model
        let s = WidgetDesignSchema.self
        model.id = UUID()
        model.schemaVersion = WidgetModel.currentSchemaVersion
        model.createdAt = now
        model.modifiedAt = now
        model.sourceLink = nil
        model.shape = option.shape
        let preset = option.sizePreset.flatMap(WidgetSizePreset.init(rawValue:)).flatMap { s.sizePresets.contains($0) ? $0 : nil } ?? s.defaultPreset(for: option.shape)
        let dimensions = preset.dimensions ?? CGSize(width: 158, height: 158)
        model.size = WidgetSize(preset: preset, width: dimensions.width, height: dimensions.height)
        let name = Self.clip(model.name, to: s.maxNameLength)
        model.name = name.isEmpty || name == WidgetModel().name ? "\(option.shape.title) \(index + 1)" : name
        model.image = WidgetImage()
        model.placement = WidgetPlacement()
        model.cornerRadius = WidgetModel().cornerRadius
        model.borderWidth = WidgetModel().borderWidth
        model.borderOpacity = WidgetModel().borderOpacity
        model.background = option.hasBackground ? sanitize(model.background, palette: palette, index: index) : Self.placeholderBackground(palette: palette, index: index)
        model.overlay = WidgetOverlay(
            direction: model.overlay.direction,
            opacity: Self.clamp(model.overlay.opacity, s.overlayOpacity),
            color: Self.normalizedHex(model.overlay.color) ?? "#000000",
            extent: Self.clamp(model.overlay.extent, s.overlayExtent)
        )
        model.glass = WidgetGlass(
            tintColor: Self.normalizedHex(model.glass.tintColor) ?? "#FFFFFF",
            tintOpacity: Self.clamp(model.glass.tintOpacity, s.tintOpacity),
            blurRadius: 0,
            rimHighlightOpacity: Self.clamp(model.glass.rimHighlightOpacity, s.rimOpacity),
            shadow: WidgetShadow()
        )
        model.textLayers = model.textLayers.compactMap(sanitize).prefix(s.maxTextLayers).map { $0 }
        return model
    }

    private func sanitize(_ background: WidgetBackground, palette: [String], index: Int) -> WidgetBackground {
        let placeholder = Self.placeholderBackground(palette: palette, index: index)
        var colors = background.gradient.colors.compactMap(Self.normalizedHex)
        colors = Array(colors.prefix(WidgetDesignSchema.gradientColorRange.upperBound))
        for fill in placeholder.gradient.colors where colors.count < WidgetDesignSchema.gradientColorRange.lowerBound {
            colors.append(fill)
        }
        var angle = background.gradient.angle.isFinite ? background.gradient.angle.truncatingRemainder(dividingBy: 360) : placeholder.gradient.angle
        if angle < 0 { angle += 360 }
        let kind: WidgetBackgroundKind = background.kind == .solid ? .solid : .linearGradient
        return WidgetBackground(
            kind: kind,
            color: Self.normalizedHex(background.color) ?? colors.first ?? placeholder.color,
            gradient: WidgetGradient(colors: colors, angle: angle)
        )
    }

    private func sanitize(_ layer: WidgetTextLayer) -> WidgetTextLayer? {
        let s = WidgetDesignSchema.self
        let content = Self.clip(layer.content, to: s.maxTextLength)
        guard !content.isEmpty else { return nil }
        let family = WidgetFonts.families.first { $0.lowercased() == layer.fontName.lowercased() } ?? "System"
        return WidgetTextLayer(
            content: content,
            fontName: family,
            size: Self.clamp(layer.size, s.textSize),
            weight: layer.weight,
            color: Self.normalizedHex(layer.color) ?? "#FFFFFF",
            alignment: layer.alignment,
            x: Self.clamp(layer.x, s.textPosition),
            y: Self.clamp(layer.y, s.textPosition),
            opacity: Self.clamp(layer.opacity, s.textOpacity)
        )
    }
}
