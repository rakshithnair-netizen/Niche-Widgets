import Foundation
import Testing
@testable import Niche_Widgets

struct ResponseParserTests {
    static func option(_ shape: String, preset: String = "small", name: String = "Option") -> String {
        """
        {"name": "\(name)", "shape": "\(shape)", "sizePreset": "\(preset)",
         "background": {"kind": "linearGradient", "color": "#7A1F2B", "gradient": {"colors": ["#7A1F2B", "#E8B04A"], "angle": 135}},
         "overlay": {"direction": "bottom", "opacity": 0.4, "color": "#000000", "extent": 0.6},
         "glass": {"tintColor": "#FFFFFF", "tintOpacity": 0.1, "rimHighlightOpacity": 0.5},
         "textLayers": [{"content": "09:41", "fontName": "System Rounded", "size": 32, "weight": "semibold", "color": "#FFFFFF", "alignment": "leading", "x": 0.1, "y": 0.4}]}
        """
    }

    static var validReply: String {
        let options = [
            option("widePill", preset: "medium", name: "Cherry Clock"),
            option("square", name: "Spot Date"),
            option("circle", name: "Pit Orb"),
            option("tallCard", preset: "large", name: "Leopard Notes"),
            option("roundedRect", preset: "extraLarge", name: "Velvet Calendar"),
            option("squircle", preset: "large", name: "Gloss Weather")
        ].joined(separator: ",")
        return """
        {"aesthetic": "Glossy cherries over warm leopard print", "searchTerms": ["leopard print", "cherry aesthetic", "red gloss", "vintage kitsch", "animal print wallpaper"], "options": [\(options)]}
        """
    }

    @Test func validJSONProducesSixOptions() throws {
        let result = try ResponseParser().parse(Self.validReply)
        #expect(result.aesthetic == "Glossy cherries over warm leopard print")
        #expect(result.searchTerms.count == 5)
        #expect(result.options.count == 6)
        #expect(Set(result.options.map(\.shape)) == Set(WidgetShape.allCases))
        let pill = try #require(result.options.first)
        #expect(pill.name == "Cherry Clock")
        #expect(pill.size.preset == .medium)
        #expect(pill.size.width == 338)
        #expect(pill.background.kind == .linearGradient)
        #expect(pill.background.gradient.colors == ["#7A1F2B", "#E8B04A"])
        #expect(pill.textLayers.first?.fontName == "System Rounded")
        #expect(pill.textLayers.first?.weight == .semibold)
        #expect(pill.image.reference == nil)
        #expect(Set(result.options.map(\.id)).count == 6)
    }

    @Test func fencedJSONIsRepaired() throws {
        let fenced = "Sure! Here you go:\n```json\n\(Self.validReply)\n```\nEnjoy."
        let result = try ResponseParser().parse(fenced)
        #expect(result.options.count == 6)
    }

    @Test func thinkBlocksAreStripped() throws {
        let result = try ResponseParser().parse("<think>{ draft }</think>\n\(Self.validReply)")
        #expect(result.options.count == 6)
    }

    @Test func malformedJSONThrowsTypedError() {
        #expect(throws: ResponseParseError.malformed) {
            try ResponseParser().parse("{\"aesthetic\": \"half\", \"options\": [")
        }
        #expect(throws: ResponseParseError.malformed) {
            try ResponseParser().parse("not json at all")
        }
        #expect(throws: ResponseParseError.malformed) {
            try ResponseParser().parse("")
        }
    }

    @Test func missingFieldsUseDefaultsAndPalette() throws {
        let palette = ["#112233", "#445566", "#778899", "#AABBCC", "#DDEEFF"]
        let result = try ResponseParser(palette: palette).parse("{\"options\": [{\"shape\": \"circle\"}]}")
        #expect(result.aesthetic == ResponseParser.defaultAesthetic)
        #expect(result.searchTerms == [ResponseParser.defaultAesthetic])
        #expect(result.palette == palette)
        let option = try #require(result.options.first)
        #expect(option.shape == .circle)
        #expect(option.size.preset == WidgetDesignSchema.defaultPreset(for: .circle))
        #expect(option.name == "Circle 1")
        #expect(option.background.kind == .linearGradient)
        #expect(option.background.gradient.colors.allSatisfy(palette.contains))
        #expect(option.textLayers.isEmpty)
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let json = """
        {"aesthetic": "x", "searchTerms": ["a"], "options": [{
          "name": "\(String(repeating: "N", count: 80))", "shape": "square", "sizePreset": "custom",
          "background": {"kind": "image", "color": "nothex", "gradient": {"colors": ["#ABC", "zzz", "#123456", "#654321", "#FFFFFF"], "angle": -90}},
          "overlay": {"direction": "top", "opacity": 5, "color": "#12", "extent": -1},
          "glass": {"tintColor": "#FF0000", "tintOpacity": 3, "rimHighlightOpacity": -2},
          "textLayers": [
            {"content": "A", "fontName": "Comic Sans", "size": 400, "x": -3, "y": 9, "opacity": 0, "color": "red"},
            {"content": "   ", "size": 12},
            {"content": "B", "size": 1},
            {"content": "C"},
            {"content": "D"}
          ]}]}
        """
        let option = try #require(try ResponseParser().parse(json).options.first)
        let s = WidgetDesignSchema.self
        #expect(option.name.count == s.maxNameLength)
        #expect(option.size.preset == s.defaultPreset(for: .square))
        #expect(option.background.kind == .linearGradient)
        #expect(option.background.gradient.colors == ["#AABBCC", "#123456", "#654321"])
        #expect(option.background.gradient.angle == 270)
        #expect(option.background.color == "#AABBCC")
        #expect(option.overlay.opacity == s.overlayOpacity.upperBound)
        #expect(option.overlay.extent == s.overlayExtent.lowerBound)
        #expect(option.overlay.color == "#000000")
        #expect(option.glass.tintOpacity == s.tintOpacity.upperBound)
        #expect(option.glass.rimHighlightOpacity == 0)
        #expect(option.textLayers.count == s.maxTextLayers)
        let first = try #require(option.textLayers.first)
        #expect(first.fontName == "System")
        #expect(first.size == s.textSize.upperBound)
        #expect(first.x == s.textPosition.lowerBound)
        #expect(first.y == s.textPosition.upperBound)
        #expect(first.opacity == s.textOpacity.lowerBound)
        #expect(first.color == "#FFFFFF")
        #expect(option.textLayers[1].content == "B")
        #expect(option.textLayers[1].size == s.textSize.lowerBound)
    }

    @Test func wrongShapesAreDropped() throws {
        let json = """
        {"aesthetic": "x", "searchTerms": ["a", "b"], "options": [
          {"shape": "hexagon"}, {"name": "No shape"}, {"shape": 7}, "string option", 12,
          \(Self.option("tallCard", preset: "large", name: "Keeper")),
          {"shape": "WidePill", "name": "Case"}
        ]}
        """
        let result = try ResponseParser().parse(json)
        #expect(result.options.map(\.name) == ["Keeper", "Case"])
        #expect(result.options.map(\.shape) == [.tallCard, .widePill])
    }

    @Test func noValidOptionsThrows() {
        #expect(throws: ResponseParseError.noUsableOptions) {
            try ResponseParser().parse("{\"aesthetic\": \"x\", \"options\": [{\"shape\": \"star\"}]}")
        }
        #expect(throws: ResponseParseError.noUsableOptions) {
            try ResponseParser().parse("{}")
        }
    }

    @Test func extraOptionsAndSearchTermsAreCapped() throws {
        let options = Array(repeating: Self.option("square"), count: 9).joined(separator: ",")
        let terms = (1...12).map { "\"term \($0)\"" }.joined(separator: ",")
        let result = try ResponseParser().parse("{\"aesthetic\": \"x\", \"searchTerms\": [\(terms), \"term 1\"], \"options\": [\(options)]}")
        #expect(result.options.count == WidgetDesignSchema.optionCount)
        #expect(result.searchTerms.count == WidgetDesignSchema.searchTermRange.upperBound)
    }

    @Test func parsedOptionsRenderThroughTheRenderer() async throws {
        let result = try ResponseParser().parse(Self.validReply)
        for option in result.options {
            let image = await MainActor.run { WidgetSnapshot.render(option, image: nil, scale: 1) }
            #expect(image != nil)
        }
    }
}
