import CoreGraphics

struct RGBA: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

enum HexColor {
    static let fallback = RGBA(red: 0, green: 0, blue: 0, alpha: 1)

    static func parse(_ hex: String) -> RGBA? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let hasAlpha = text.count == 8
        let r = hasAlpha ? (value >> 24) & 0xFF : (value >> 16) & 0xFF
        let g = hasAlpha ? (value >> 16) & 0xFF : (value >> 8) & 0xFF
        let b = hasAlpha ? (value >> 8) & 0xFF : value & 0xFF
        let a = hasAlpha ? value & 0xFF : 0xFF
        return RGBA(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: Double(a) / 255)
    }

    static func cgColor(_ hex: String, opacity: Double = 1) -> CGColor {
        let rgba = parse(hex) ?? fallback
        let alpha = min(max(rgba.alpha * opacity, 0), 1)
        return CGColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: alpha)
    }

    static func string(_ rgba: RGBA) -> String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        let base = String(format: "#%02X%02X%02X", byte(rgba.red), byte(rgba.green), byte(rgba.blue))
        return rgba.alpha >= 1 ? base : base + String(format: "%02X", byte(rgba.alpha))
    }
}
