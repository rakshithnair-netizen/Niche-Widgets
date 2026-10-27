import AppKit

enum WidgetFonts {
    static let families = ["System", "System Rounded", "System Serif", "System Mono"]

    static func font(name: String, size: Double, weight: WidgetFontWeight) -> NSFont {
        let pointSize = CGFloat(max(size, 1))
        let nsWeight = weight.nsWeight
        let system = NSFont.systemFont(ofSize: pointSize, weight: nsWeight)
        switch name.lowercased() {
        case "", "system", "sf pro":
            return system
        case "system rounded", "sf pro rounded":
            return designed(system, .rounded, size: pointSize)
        case "system serif", "new york":
            return designed(system, .serif, size: pointSize)
        case "system mono", "sf mono":
            return NSFont.monospacedSystemFont(ofSize: pointSize, weight: nsWeight)
        default:
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: name,
                .traits: [NSFontDescriptor.TraitKey.weight: nsWeight]
            ])
            return NSFont(descriptor: descriptor, size: pointSize) ?? system
        }
    }

    private static func designed(_ font: NSFont, _ design: NSFontDescriptor.SystemDesign, size: CGFloat) -> NSFont {
        guard let descriptor = font.fontDescriptor.withDesign(design) else { return font }
        return NSFont(descriptor: descriptor, size: size) ?? font
    }
}

extension WidgetFontWeight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension WidgetTextAlignment {
    var textAlignment: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }

    var alignmentMode: CATextLayerAlignmentMode {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }

    var anchorX: CGFloat {
        switch self {
        case .leading: 0
        case .center: 0.5
        case .trailing: 1
        }
    }
}
