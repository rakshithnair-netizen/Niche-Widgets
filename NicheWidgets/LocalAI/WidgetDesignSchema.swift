import Foundation

enum WidgetDesignSchema {
    static let optionCount = 6
    static let searchTermRange = 5...8
    static let gradientColorRange = 2...3
    static let maxTextLayers = 2
    static let maxNameLength = 28
    static let maxTextLength = 32
    static let maxAestheticLength = 160
    static let maxSearchTermLength = 60
    static let overlayOpacity = 0.0...0.8
    static let overlayExtent = 0.2...1.0
    static let tintOpacity = 0.0...0.4
    static let rimOpacity = 0.0...1.0
    static let gradientAngle = 0.0...360.0
    static let textSize = 14.0...64.0
    static let textPosition = 0.05...0.95
    static let textOpacity = 0.3...1.0
    static let hexPattern = "^#[0-9A-Fa-f]{6}$"

    static let shapes = WidgetShape.allCases
    static let sizePresets: [WidgetSizePreset] = [.small, .medium, .large, .extraLarge]
    static let backgroundKinds: [WidgetBackgroundKind] = [.solid, .linearGradient]

    static func defaultPreset(for shape: WidgetShape) -> WidgetSizePreset {
        switch shape {
        case .widePill: .medium
        case .square, .circle: .small
        case .tallCard, .roundedRect, .squircle: .large
        }
    }

    private static func strings(_ values: [String]) -> JSONValue {
        .array(values.map(JSONValue.string))
    }

    private static var hex: JSONValue {
        ["type": "string", "pattern": .string(hexPattern)]
    }

    private static func number(_ range: ClosedRange<Double>) -> JSONValue {
        ["type": "number", "minimum": .number(range.lowerBound), "maximum": .number(range.upperBound)]
    }

    private static func enumeration(_ values: [String]) -> JSONValue {
        ["type": "string", "enum": strings(values)]
    }

    static var textLayer: JSONValue {
        [
            "type": "object",
            "properties": [
                "content": ["type": "string"],
                "fontName": enumeration(WidgetFonts.families),
                "size": number(textSize),
                "weight": enumeration(WidgetFontWeight.allCases.map(\.rawValue)),
                "color": hex,
                "alignment": enumeration(WidgetTextAlignment.allCases.map(\.rawValue)),
                "x": number(textPosition),
                "y": number(textPosition)
            ],
            "required": ["content", "fontName", "size", "weight", "color", "alignment", "x", "y"]
        ]
    }

    static var option: JSONValue {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "shape": enumeration(shapes.map(\.rawValue)),
                "sizePreset": enumeration(sizePresets.map(\.rawValue)),
                "background": [
                    "type": "object",
                    "properties": [
                        "kind": enumeration(backgroundKinds.map(\.rawValue)),
                        "color": hex,
                        "gradient": [
                            "type": "object",
                            "properties": [
                                "colors": ["type": "array", "items": hex, "minItems": .number(Double(gradientColorRange.lowerBound)), "maxItems": .number(Double(gradientColorRange.upperBound))],
                                "angle": number(gradientAngle)
                            ],
                            "required": ["colors", "angle"]
                        ]
                    ],
                    "required": ["kind", "color", "gradient"]
                ],
                "overlay": [
                    "type": "object",
                    "properties": [
                        "direction": enumeration(WidgetScrimDirection.allCases.map(\.rawValue)),
                        "opacity": number(overlayOpacity),
                        "color": hex,
                        "extent": number(overlayExtent)
                    ],
                    "required": ["direction", "opacity", "color", "extent"]
                ],
                "glass": [
                    "type": "object",
                    "properties": [
                        "tintColor": hex,
                        "tintOpacity": number(tintOpacity),
                        "rimHighlightOpacity": number(rimOpacity)
                    ],
                    "required": ["tintColor", "tintOpacity", "rimHighlightOpacity"]
                ],
                "textLayers": ["type": "array", "items": textLayer, "maxItems": .number(Double(maxTextLayers))]
            ],
            "required": ["name", "shape", "sizePreset", "background", "overlay", "glass", "textLayers"]
        ]
    }

    static var reply: JSONValue {
        [
            "type": "object",
            "properties": [
                "aesthetic": ["type": "string"],
                "searchTerms": ["type": "array", "items": ["type": "string"], "minItems": .number(Double(searchTermRange.lowerBound)), "maxItems": .number(Double(searchTermRange.upperBound))],
                "options": ["type": "array", "items": option, "minItems": .number(Double(optionCount)), "maxItems": .number(Double(optionCount))]
            ],
            "required": ["aesthetic", "searchTerms", "options"]
        ]
    }
}
