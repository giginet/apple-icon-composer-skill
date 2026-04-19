import Foundation

// MARK: - Icon Model (matches icon.json structure)

struct IconDocument: Codable, Sendable {
    var fill: Fill?
    var fillSpecializations: [Specialization<FillOrAutomatic>]?
    var colorSpaceForUntaggedSVGColors: String?
    var groups: [Group]
    var supportedPlatforms: SupportedPlatforms

    enum CodingKeys: String, CodingKey {
        case fill
        case fillSpecializations = "fill-specializations"
        case colorSpaceForUntaggedSVGColors = "color-space-for-untagged-svg-colors"
        case groups
        case supportedPlatforms = "supported-platforms"
    }
}

// MARK: - Fill

struct Fill: Codable, Sendable {
    var automaticGradient: String?
    var solid: String?
    var linearGradient: [String]?

    enum CodingKeys: String, CodingKey {
        case automaticGradient = "automatic-gradient"
        case solid
        case linearGradient = "linear-gradient"
    }
}

// MARK: - Specialization

struct Specialization<Value: Codable & Sendable>: Codable, Sendable {
    var appearance: String?
    var value: Value
}

// A value that is either T or the literal string "automatic".
enum OrAutomatic<T: Codable & Sendable>: Codable, Sendable {
    case value(T)
    case automatic

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self), s == "automatic" {
            self = .automatic
            return
        }
        let v = try container.decode(T.self)
        self = .value(v)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .automatic:
            try container.encode("automatic")
        case .value(let v):
            try container.encode(v)
        }
    }
}

typealias FillOrAutomatic = OrAutomatic<Fill>
typealias StringOrAutomatic = OrAutomatic<String>
typealias BoolOrAutomatic = OrAutomatic<Bool>
typealias DoubleOrAutomatic = OrAutomatic<Double>
typealias PositionOrAutomatic = OrAutomatic<Position>

// MARK: - Layer

struct Layer: Codable, Sendable {
    var name: String
    var imageName: String?
    var imageNameSpecializations: [Specialization<StringOrAutomatic>]?
    var fill: Fill?
    var fillSpecializations: [Specialization<FillOrAutomatic>]?
    var glass: Bool?
    var glassSpecializations: [Specialization<BoolOrAutomatic>]?
    var hidden: Bool?
    var hiddenSpecializations: [Specialization<BoolOrAutomatic>]?
    var blendMode: String?
    var blendModeSpecializations: [Specialization<StringOrAutomatic>]?
    var position: Position?
    var positionSpecializations: [Specialization<PositionOrAutomatic>]?

    enum CodingKeys: String, CodingKey {
        case name
        case imageName = "image-name"
        case imageNameSpecializations = "image-name-specializations"
        case fill
        case fillSpecializations = "fill-specializations"
        case glass
        case glassSpecializations = "glass-specializations"
        case hidden
        case hiddenSpecializations = "hidden-specializations"
        case blendMode = "blend-mode"
        case blendModeSpecializations = "blend-mode-specializations"
        case position
        case positionSpecializations = "position-specializations"
    }
}

struct Position: Codable, Sendable {
    var scale: Double?
    var translationInPoints: [Double]?

    enum CodingKeys: String, CodingKey {
        case scale
        case translationInPoints = "translation-in-points"
    }
}

// MARK: - Group and effects

struct Shadow: Codable, Sendable {
    var kind: String
    var opacity: Double
    var kindSpecializations: [Specialization<StringOrAutomatic>]?
    var opacitySpecializations: [Specialization<DoubleOrAutomatic>]?

    enum CodingKeys: String, CodingKey {
        case kind, opacity
        case kindSpecializations = "kind-specializations"
        case opacitySpecializations = "opacity-specializations"
    }
}

struct Translucency: Codable, Sendable {
    var enabled: Bool
    var value: Double
    var enabledSpecializations: [Specialization<BoolOrAutomatic>]?
    var valueSpecializations: [Specialization<DoubleOrAutomatic>]?

    enum CodingKeys: String, CodingKey {
        case enabled, value
        case enabledSpecializations = "enabled-specializations"
        case valueSpecializations = "value-specializations"
    }
}

struct Group: Codable, Sendable {
    var layers: [Layer]
    var lighting: String?
    var lightingSpecializations: [Specialization<StringOrAutomatic>]?
    var shadow: Shadow
    var translucency: Translucency

    enum CodingKeys: String, CodingKey {
        case layers, lighting
        case lightingSpecializations = "lighting-specializations"
        case shadow, translucency
    }
}

struct SupportedPlatforms: Codable, Sendable {
    var squares: String
    var circles: [String]?
}
