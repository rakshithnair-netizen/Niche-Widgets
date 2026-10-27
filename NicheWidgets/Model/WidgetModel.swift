import Foundation
import CoreGraphics

enum WidgetShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case square, widePill, tallCard, circle, roundedRect, squircle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Square"
        case .widePill: "Wide Pill"
        case .tallCard: "Tall Card"
        case .circle: "Circle"
        case .roundedRect: "Rounded Rect"
        case .squircle: "Squircle"
        }
    }
}

enum WidgetSizePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .custom: "Custom"
        }
    }

    var dimensions: CGSize? {
        switch self {
        case .small: CGSize(width: 158, height: 158)
        case .medium: CGSize(width: 338, height: 158)
        case .large: CGSize(width: 338, height: 338)
        case .extraLarge: CGSize(width: 698, height: 338)
        case .custom: nil
        }
    }
}

struct WidgetSize: Codable, Hashable, Sendable {
    var preset = WidgetSizePreset.small
    var width = 158.0
    var height = 158.0

    var requested: CGSize {
        preset.dimensions ?? CGSize(width: width, height: height)
    }
}

enum WidgetBackgroundKind: String, Codable, CaseIterable, Sendable {
    case solid, linearGradient, image
}

struct WidgetGradient: Codable, Hashable, Sendable {
    var colors = ["#2B3040", "#6B7590"]
    var angle = 135.0
}

struct WidgetBackground: Codable, Hashable, Sendable {
    var kind = WidgetBackgroundKind.linearGradient
    var color = "#1C1C22"
    var gradient = WidgetGradient()
}

enum WidgetImageFit: String, Codable, CaseIterable, Sendable {
    case fill, fit
}

struct WidgetImage: Codable, Hashable, Sendable {
    var reference: String? = nil
    var fit = WidgetImageFit.fill
    var zoom = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
    var rotation = 0.0
}

enum WidgetScrimDirection: String, Codable, CaseIterable, Sendable {
    case top, bottom, leading, trailing
}

struct WidgetOverlay: Codable, Hashable, Sendable {
    var direction = WidgetScrimDirection.bottom
    var opacity = 0.0
    var color = "#000000"
    var extent = 0.65
}

struct WidgetShadow: Codable, Hashable, Sendable {
    var radius = 16.0
    var opacity = 0.35
    var offsetX = 0.0
    var offsetY = 8.0
}

struct WidgetGlass: Codable, Hashable, Sendable {
    var tintColor = "#FFFFFF"
    var tintOpacity = 0.0
    var blurRadius = 0.0
    var rimHighlightOpacity = 0.35
    var shadow = WidgetShadow()
}

enum WidgetFontWeight: String, Codable, CaseIterable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

enum WidgetTextAlignment: String, Codable, CaseIterable, Sendable {
    case leading, center, trailing
}

struct WidgetTextLayer: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var content = ""
    var fontName = "System"
    var size = 17.0
    var weight = WidgetFontWeight.regular
    var color = "#FFFFFF"
    var alignment = WidgetTextAlignment.leading
    var x = 0.5
    var y = 0.5
    var opacity = 1.0
}

struct WidgetPlacement: Codable, Hashable, Sendable {
    var x = 0.0
    var y = 0.0
    var displayID: UInt32? = nil
}

struct WidgetModel: Codable, Hashable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = WidgetModel.currentSchemaVersion
    var id = UUID()
    var name = "Untitled Widget"
    var createdAt = Date()
    var modifiedAt = Date()
    var sourceLink: String? = nil
    var shape = WidgetShape.roundedRect
    var size = WidgetSize()
    var cornerRadius = 24.0
    var borderWidth = 1.0
    var borderOpacity = 0.12
    var background = WidgetBackground()
    var image = WidgetImage()
    var overlay = WidgetOverlay()
    var glass = WidgetGlass()
    var textLayers: [WidgetTextLayer] = []
    var placement = WidgetPlacement()

    var resolvedSize: CGSize {
        WidgetSizing.clamp(size.requested, shape: shape)
    }
}

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, or fallback: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback()
    }

    func optionalValue<T: Decodable>(_ key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }
}

extension WidgetModel {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetModel()
        schemaVersion = c.value(.schemaVersion, or: d.schemaVersion)
        id = c.value(.id, or: d.id)
        name = c.value(.name, or: d.name)
        createdAt = c.value(.createdAt, or: d.createdAt)
        modifiedAt = c.value(.modifiedAt, or: d.modifiedAt)
        sourceLink = c.optionalValue(.sourceLink)
        shape = c.value(.shape, or: d.shape)
        size = c.value(.size, or: d.size)
        cornerRadius = c.value(.cornerRadius, or: d.cornerRadius)
        borderWidth = c.value(.borderWidth, or: d.borderWidth)
        borderOpacity = c.value(.borderOpacity, or: d.borderOpacity)
        background = c.value(.background, or: d.background)
        image = c.value(.image, or: d.image)
        overlay = c.value(.overlay, or: d.overlay)
        glass = c.value(.glass, or: d.glass)
        textLayers = c.value(.textLayers, or: d.textLayers)
        placement = c.value(.placement, or: d.placement)
    }
}

extension WidgetSize {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetSize()
        preset = c.value(.preset, or: d.preset)
        width = c.value(.width, or: d.width)
        height = c.value(.height, or: d.height)
    }
}

extension WidgetGradient {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetGradient()
        colors = c.value(.colors, or: d.colors)
        angle = c.value(.angle, or: d.angle)
    }
}

extension WidgetBackground {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetBackground()
        kind = c.value(.kind, or: d.kind)
        color = c.value(.color, or: d.color)
        gradient = c.value(.gradient, or: d.gradient)
    }
}

extension WidgetImage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetImage()
        reference = c.optionalValue(.reference)
        fit = c.value(.fit, or: d.fit)
        zoom = c.value(.zoom, or: d.zoom)
        offsetX = c.value(.offsetX, or: d.offsetX)
        offsetY = c.value(.offsetY, or: d.offsetY)
        rotation = c.value(.rotation, or: d.rotation)
    }
}

extension WidgetOverlay {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetOverlay()
        direction = c.value(.direction, or: d.direction)
        opacity = c.value(.opacity, or: d.opacity)
        color = c.value(.color, or: d.color)
        extent = c.value(.extent, or: d.extent)
    }
}

extension WidgetShadow {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetShadow()
        radius = c.value(.radius, or: d.radius)
        opacity = c.value(.opacity, or: d.opacity)
        offsetX = c.value(.offsetX, or: d.offsetX)
        offsetY = c.value(.offsetY, or: d.offsetY)
    }
}

extension WidgetGlass {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetGlass()
        tintColor = c.value(.tintColor, or: d.tintColor)
        tintOpacity = c.value(.tintOpacity, or: d.tintOpacity)
        blurRadius = c.value(.blurRadius, or: d.blurRadius)
        rimHighlightOpacity = c.value(.rimHighlightOpacity, or: d.rimHighlightOpacity)
        shadow = c.value(.shadow, or: d.shadow)
    }
}

extension WidgetTextLayer {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetTextLayer()
        id = c.value(.id, or: d.id)
        content = c.value(.content, or: d.content)
        fontName = c.value(.fontName, or: d.fontName)
        size = c.value(.size, or: d.size)
        weight = c.value(.weight, or: d.weight)
        color = c.value(.color, or: d.color)
        alignment = c.value(.alignment, or: d.alignment)
        x = c.value(.x, or: d.x)
        y = c.value(.y, or: d.y)
        opacity = c.value(.opacity, or: d.opacity)
    }
}

extension WidgetPlacement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetPlacement()
        x = c.value(.x, or: d.x)
        y = c.value(.y, or: d.y)
        displayID = c.optionalValue(.displayID)
    }
}
