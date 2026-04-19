import Foundation
import MCP

enum ToolHandlers {

    // MARK: - read_icon

    static func readIcon(arguments: [String: Value]?) throws -> CallTool.Result {
        guard let path = arguments?["path"]?.stringValue else {
            return errorResult("'path' parameter is required")
        }

        let iconURL = URL(fileURLWithPath: path)
        let jsonURL = iconURL.appendingPathComponent("icon.json")

        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return errorResult("icon.json not found at \(jsonURL.path)")
        }

        let jsonData = try Data(contentsOf: jsonURL)

        // Decode for validation / structural check, then re-serialize the parsed form
        // so callers get a well-structured response even if the original JSON had
        // incidental formatting. We also collect the asset file list.
        let document = try JSONDecoder().decode(IconDocument.self, from: jsonData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encodedDocument = try encoder.encode(document)
        let iconJSONObject = try JSONSerialization.jsonObject(with: encodedDocument)

        let assetsURL = iconURL.appendingPathComponent("Assets")
        var assetFiles: [String] = []
        if let enumerator = FileManager.default.enumerator(atPath: assetsURL.path) {
            while let file = enumerator.nextObject() as? String {
                assetFiles.append(file)
            }
        }
        assetFiles.sort()

        let response: [String: Any] = [
            "path": path,
            "icon": iconJSONObject,
            "assets": assetFiles,
            "group_count": document.groups.count,
            "layer_count": document.groups.reduce(0) { $0 + $1.layers.count },
        ]

        let responseData = try JSONSerialization.data(
            withJSONObject: response, options: [.prettyPrinted, .sortedKeys])
        let responseString = String(data: responseData, encoding: .utf8) ?? "{}"

        return .init(
            content: [.text(responseString)],
            isError: false
        )
    }

    // MARK: - create_icon

    static func createIcon(arguments: [String: Value]?) throws -> CallTool.Result {
        guard let args = arguments else {
            return errorResult("arguments required")
        }

        guard let outputPath = args["output_path"]?.stringValue else {
            return errorResult("'output_path' is required")
        }

        guard outputPath.hasSuffix(".icon") else {
            return errorResult("output_path must end with .icon")
        }

        guard let iconValue = args["icon"] else {
            return errorResult("'icon' is required")
        }

        guard let assetsValue = args["assets"], case .object(let assetsMap) = assetsValue else {
            return errorResult("'assets' is required and must be an object")
        }

        // Decode and validate the icon document by round-tripping through Codable.
        let document = try ValueJSON.decode(IconDocument.self, from: iconValue)

        // Verify every image-name referenced by layers has a matching asset entry.
        let referencedNames = referencedImageNames(in: document)
        let providedNames = Set(assetsMap.keys)
        let missing = referencedNames.subtracting(providedNames).sorted()
        if !missing.isEmpty {
            return errorResult(
                "Missing asset data for image-name(s): \(missing.joined(separator: ", "))")
        }

        // Build directory structure.
        let iconURL = URL(fileURLWithPath: outputPath)
        let assetsURL = iconURL.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        // Write each asset.
        for (filename, value) in assetsMap {
            guard let base64 = value.stringValue else {
                return errorResult("asset '\(filename)' must be a base64 string")
            }
            guard let data = Data(base64Encoded: base64) else {
                return errorResult("asset '\(filename)' is not valid base64")
            }
            let fileURL = assetsURL.appendingPathComponent(filename)
            try data.write(to: fileURL)
        }

        // Serialize icon.json (re-encoded from the decoded model so the output is canonical).
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(document)
        let jsonURL = iconURL.appendingPathComponent("icon.json")
        try jsonData.write(to: jsonURL)

        let summary: [String: Any] = [
            "path": outputPath,
            "assets_written": assetsMap.keys.sorted(),
            "group_count": document.groups.count,
            "layer_count": document.groups.reduce(0) { $0 + $1.layers.count },
        ]
        let data = try JSONSerialization.data(
            withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: data, encoding: .utf8) ?? "{}"

        return .init(
            content: [.text("Icon created at \(outputPath)\n\(text)")],
            isError: false
        )
    }

    // MARK: - Helpers

    private static func errorResult(_ message: String) -> CallTool.Result {
        .init(
            content: [.text("Error: \(message)")],
            isError: true
        )
    }

    /// Collect every filename referenced by the icon document, including from
    /// `image-name-specializations` entries whose value is a concrete string.
    private static func referencedImageNames(in document: IconDocument) -> Set<String> {
        var names = Set<String>()
        for group in document.groups {
            for layer in group.layers {
                if let name = layer.imageName { names.insert(name) }
                if let specs = layer.imageNameSpecializations {
                    for spec in specs {
                        if case .value(let s) = spec.value { names.insert(s) }
                    }
                }
            }
        }
        return names
    }
}
