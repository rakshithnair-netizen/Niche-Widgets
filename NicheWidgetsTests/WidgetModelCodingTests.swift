import Foundation
import Testing
@testable import Niche_Widgets

struct WidgetModelCodingTests {
    private func decode(_ json: String) throws -> WidgetModel {
        try WidgetModel.makeDecoder().decode(WidgetModel.self, from: Data(json.utf8))
    }

    @Test func roundTripPreservesEverySample() throws {
        let encoder = WidgetModel.makeEncoder()
        let decoder = WidgetModel.makeDecoder()
        for model in SampleWidgets.make() {
            let data = try encoder.encode(model)
            let decoded = try decoder.decode(WidgetModel.self, from: data)
            #expect(decoded == model)
        }
    }

    @Test func roundTripPreservesNonDefaultValues() throws {
        var model = WidgetModel()
        model.sourceLink = "https://example.com/pin/1"
        model.shape = .tallCard
        model.size = WidgetSize(preset: .custom, width: 240, height: 410)
        model.image = WidgetImage(reference: "cache-key", fit: .fit, zoom: 1.6, offsetX: -0.1, offsetY: 0.2, rotation: 12)
        model.overlay = WidgetOverlay(direction: .trailing, opacity: 0.4, color: "#102030", extent: 0.3)
        model.glass = WidgetGlass(tintColor: "#FF00FF", tintOpacity: 0.2, blurRadius: 4, rimHighlightOpacity: 0.8, shadow: WidgetShadow(radius: 3, opacity: 0.9, offsetX: 1, offsetY: 2))
        model.placement = WidgetPlacement(x: 40, y: 80, displayID: 7)
        let data = try WidgetModel.makeEncoder().encode(model)
        #expect(try WidgetModel.makeDecoder().decode(WidgetModel.self, from: data) == model)
    }

    @Test func emptyObjectDecodesWithDefaults() throws {
        let model = try decode("{}")
        let defaults = WidgetModel()
        #expect(model.schemaVersion == WidgetModel.currentSchemaVersion)
        #expect(model.name == defaults.name)
        #expect(model.shape == defaults.shape)
        #expect(model.size == defaults.size)
        #expect(model.cornerRadius == defaults.cornerRadius)
        #expect(model.background == defaults.background)
        #expect(model.image == defaults.image)
        #expect(model.overlay == defaults.overlay)
        #expect(model.glass == defaults.glass)
        #expect(model.textLayers.isEmpty)
        #expect(model.placement == defaults.placement)
        #expect(model.sourceLink == nil)
    }

    @Test func missingNestedFieldsUseDefaults() throws {
        let model = try decode("""
        {
          "name": "Partial",
          "shape": "circle",
          "glass": { "tintOpacity": 0.5, "shadow": { "radius": 2 } },
          "size": { "preset": "custom", "width": 300 },
          "textLayers": [ { "content": "Hi" } ]
        }
        """)
        #expect(model.name == "Partial")
        #expect(model.shape == .circle)
        #expect(model.glass.tintOpacity == 0.5)
        #expect(model.glass.tintColor == WidgetGlass().tintColor)
        #expect(model.glass.shadow.radius == 2)
        #expect(model.glass.shadow.opacity == WidgetShadow().opacity)
        #expect(model.size.width == 300)
        #expect(model.size.height == WidgetSize().height)
        #expect(model.textLayers.count == 1)
        #expect(model.textLayers[0].content == "Hi")
        #expect(model.textLayers[0].size == WidgetTextLayer().size)
        #expect(model.textLayers[0].alignment == .leading)
    }

    @Test func unknownFieldsAreIgnored() throws {
        let model = try decode("""
        {
          "name": "Future",
          "schemaVersion": 9,
          "animation": { "kind": "wobble", "speed": 3 },
          "glass": { "rimHighlightOpacity": 0.7, "refraction": 1.2 },
          "textLayers": [ { "content": "A", "kerning": 2 } ],
          "tags": ["x", "y"]
        }
        """)
        #expect(model.name == "Future")
        #expect(model.schemaVersion == 9)
        #expect(model.glass.rimHighlightOpacity == 0.7)
        #expect(model.textLayers.first?.content == "A")
    }

    @Test func invalidValuesFallBackToDefaults() throws {
        let model = try decode("""
        { "shape": "hexagon", "cornerRadius": "round", "background": { "kind": "video" } }
        """)
        #expect(model.shape == WidgetModel().shape)
        #expect(model.cornerRadius == WidgetModel().cornerRadius)
        #expect(model.background.kind == WidgetBackground().kind)
    }

    @Test func hexColorsParse() {
        #expect(HexColor.parse("#FF8000") == RGBA(red: 1, green: 128.0 / 255, blue: 0, alpha: 1))
        #expect(HexColor.parse("#0000FF80")?.alpha == 128.0 / 255)
        #expect(HexColor.parse("#FFF") == RGBA(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(HexColor.parse("nope") == nil)
        #expect(HexColor.string(RGBA(red: 1, green: 0.5, blue: 0, alpha: 1)) == "#FF8000")
    }
}
