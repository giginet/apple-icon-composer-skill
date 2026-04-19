import MCP

enum ToolSchemas {
    /// Input schema for `create_icon`.
    ///
    /// The tool takes two primary payloads:
    ///   - `icon`: the full icon.json document (matches the .icon JSON schema)
    ///   - `assets`: a map of filename -> base64-encoded image data
    static let createIcon = Tool(
        name: "create_icon",
        description: """
            Create an Apple Icon Composer .icon package. \
            Provide the icon.json document and base64-encoded image assets. \
            The .icon package (a directory) will be created at output_path.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "output_path": .object([
                    "type": .string("string"),
                    "description": .string("Output path for the .icon package (must end with .icon)"),
                ]),
                "icon": .object([
                    "type": .string("object"),
                    "description": .string(
                        """
                        The icon.json document. Top-level keys include: \
                        'groups' (required, array of layer groups), \
                        'supported-platforms' (required), \
                        'fill' or 'fill-specializations' (background fill), \
                        'color-space-for-untagged-svg-colors'. \
                        Each group contains 'layers', 'shadow', 'translucency', optional 'lighting'. \
                        Layers reference assets by 'image-name' (or 'image-name-specializations' for per-appearance assets). \
                        Any scalar property may have an appearance-specific override via a '-specializations' array \
                        whose items are { appearance?: 'dark' | 'tinted', value: T | 'automatic' }.
                        """
                    ),
                ]),
                "assets": .object([
                    "type": .string("object"),
                    "description": .string(
                        "Map of image filename to base64-encoded data. Every 'image-name' referenced by layers must appear here. Example: { \"icon.png\": \"<base64>\" }"
                    ),
                    "additionalProperties": .object([
                        "type": .string("string"),
                        "description": .string("Base64-encoded image bytes"),
                    ]),
                ]),
            ]),
            "required": .array([
                .string("output_path"),
                .string("icon"),
                .string("assets"),
            ]),
        ])
    )

    static let readIcon = Tool(
        name: "read_icon",
        description:
            "Read an Apple Icon Composer .icon package and return its icon.json plus the list of asset filenames.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .icon package to read"),
                ])
            ]),
            "required": .array([.string("path")]),
        ])
    )
}
