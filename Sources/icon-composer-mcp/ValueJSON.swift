import Foundation
import MCP

enum ValueJSON {
    /// Convert an MCP `Value` to a Foundation JSON object suitable for `JSONSerialization`.
    static func toJSONObject(_ value: Value) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let a):
            return a.map { toJSONObject($0) }
        case .object(let o):
            var dict: [String: Any] = [:]
            for (k, v) in o { dict[k] = toJSONObject(v) }
            return dict
        case .data(mimeType: _, let data):
            return data.base64EncodedString()
        }
    }

    /// Serialize an MCP `Value` to JSON `Data`.
    static func toData(_ value: Value) throws -> Data {
        let object = toJSONObject(value)
        return try JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// Decode an MCP `Value` into a Codable type via JSON round-trip.
    static func decode<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
        let data = try toData(value)
        return try JSONDecoder().decode(type, from: data)
    }
}
