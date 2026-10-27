import Foundation

indirect enum JSONValue: Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([(String, JSONValue)])
    case null

    static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case let (.string(a), .string(b)): a == b
        case let (.number(a), .number(b)): a == b
        case let (.bool(a), .bool(b)): a == b
        case let (.array(a), .array(b)): a == b
        case let (.object(a), .object(b)): a.map(\.0) == b.map(\.0) && a.map(\.1) == b.map(\.1)
        case (.null, .null): true
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let value): hasher.combine(value)
        case .number(let value): hasher.combine(value)
        case .bool(let value): hasher.combine(value)
        case .array(let value): hasher.combine(value)
        case .object(let pairs):
            for (key, value) in pairs {
                hasher.combine(key)
                hasher.combine(value)
            }
        case .null: hasher.combine(0)
        }
    }

    func compactString() -> String {
        var output = ""
        write(into: &output)
        return output
    }

    func data() -> Data {
        Data(compactString().utf8)
    }

    private func write(into output: inout String) {
        switch self {
        case .string(let value):
            Self.writeString(value, into: &output)
        case .number(let value):
            if !value.isFinite {
                output += "0"
            } else if value.rounded() == value, abs(value) < 1e15 {
                output += String(Int(value))
            } else {
                output += String(value)
            }
        case .bool(let value):
            output += value ? "true" : "false"
        case .array(let values):
            output += "["
            for (index, value) in values.enumerated() {
                if index > 0 { output += "," }
                value.write(into: &output)
            }
            output += "]"
        case .object(let pairs):
            output += "{"
            for (index, pair) in pairs.enumerated() {
                if index > 0 { output += "," }
                Self.writeString(pair.0, into: &output)
                output += ":"
                pair.1.write(into: &output)
            }
            output += "}"
        case .null:
            output += "null"
        }
    }

    private static func writeString(_ value: String, into output: inout String) {
        output += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            default:
                if scalar.value < 0x20 {
                    output += String(format: "\\u%04X", scalar.value)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        output += "\""
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(floatLiteral value: Double) { self = .number(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(elements) }
}
