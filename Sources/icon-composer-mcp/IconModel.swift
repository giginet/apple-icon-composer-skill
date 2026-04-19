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

// A layer within a group. Most scalar properties can be specialized per
// appearance via '-specializations': Color (fill, blend-mode, opacity),
// LiquidGlass (glass), Composition.Visible (hidden), Composition.Layout
// (image-name, position).
struct Layer: Codable, Sendable {
    var name: String
    var imageName: String?
    var imageNameSpecializations: [Specialization<StringOrAutomatic>]?
    var fill: Fill?
    var fillSpecializations: [Specialization<FillOrAutomatic>]?
    var blendMode: String?
    var blendModeSpecializations: [Specialization<StringOrAutomatic>]?
    var opacity: Double?
    var opacitySpecializations: [Specialization<DoubleOrAutomatic>]?
    var glass: Bool?
    var glassSpecializations: [Specialization<BoolOrAutomatic>]?
    var hidden: Bool?
    var hiddenSpecializations: [Specialization<BoolOrAutomatic>]?
    var position: Position?
    var positionSpecializations: [Specialization<PositionOrAutomatic>]?

    enum CodingKeys: String, CodingKey {
        case name
        case imageName = "image-name"
        case imageNameSpecializations = "image-name-specializations"
        case fill
        case fillSpecializations = "fill-specializations"
        case blendMode = "blend-mode"
        case blendModeSpecializations = "blend-mode-specializations"
        case opacity
        case opacitySpecializations = "opacity-specializations"
        case glass
        case glassSpecializations = "glass-specializations"
        case hidden
        case hiddenSpecializations = "hidden-specializations"
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

// A group carries the 5 LiquidGlass properties (Mode/lighting, Specular,
// Blur, Translucency, Shadow) plus a Composition.Layout position, each
// with a '-specializations' sibling for per-appearance overrides.
struct Group: Codable, Sendable {
    var layers: [Layer]
    var lighting: String?
    var lightingSpecializations: [Specialization<StringOrAutomatic>]?
    var specular: Bool?
    var specularSpecializations: [Specialization<BoolOrAutomatic>]?
    var blur: Double?
    var blurSpecializations: [Specialization<DoubleOrAutomatic>]?
    var position: Position?
    var positionSpecializations: [Specialization<PositionOrAutomatic>]?
    var shadow: Shadow
    var translucency: Translucency

    enum CodingKeys: String, CodingKey {
        case layers, lighting
        case lightingSpecializations = "lighting-specializations"
        case specular
        case specularSpecializations = "specular-specializations"
        case blur
        case blurSpecializations = "blur-specializations"
        case position
        case positionSpecializations = "position-specializations"
        case shadow, translucency
    }
}

struct SupportedPlatforms: Codable, Sendable {
    var squares: String
    var circles: [String]?
}
