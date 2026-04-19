import MCP

let server = Server(
    name: "icon-composer-mcp",
    version: "0.1.0",
    capabilities: .init(
        tools: .init(listChanged: false)
    )
)

await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: [
        ToolSchemas.createIcon,
        ToolSchemas.readIcon,
    ])
}

await server.withMethodHandler(CallTool.self) { params in
    do {
        switch params.name {
        case "create_icon":
            return try ToolHandlers.createIcon(arguments: params.arguments)
        case "read_icon":
            return try ToolHandlers.readIcon(arguments: params.arguments)
        default:
            return .init(
                content: [.text("Unknown tool: \(params.name)")],
                isError: true
            )
        }
    } catch {
        return .init(
            content: [.text("Error: \(error.localizedDescription)")],
            isError: true
        )
    }
}

let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
