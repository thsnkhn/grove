import Foundation
import MCP
import Testing
@testable import Grove

@Test @MainActor
func httpClientsCanInitializeIndependently() async throws {
    let server = GroveServer(store: EventKitStore())
    let request = HTTPRequest(
        method: "POST",
        headers: ["Content-Type": "application/json", "Accept": "application/json"],
        body: Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#.utf8),
        path: "/mcp"
    )
    for _ in 0..<2 {
        let response = try await server.handle(request)
        #expect(response.statusCode == 200)
        let data = try #require(response.bodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["error"] == nil)
        #expect(json["result"] != nil)
    }
    let listRequest = HTTPRequest(
        method: "POST",
        headers: ["Content-Type": "application/json", "Accept": "application/json"],
        body: Data(#"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#.utf8),
        path: "/mcp"
    )
    async let initialize = server.handle(request)
    async let list = server.handle(listRequest)
    let (initializeResponse, listResponse) = try await (initialize, list)
    let initializeData = try #require(initializeResponse.bodyData)
    let listData = try #require(listResponse.bodyData)
    #expect(String(decoding: initializeData, as: UTF8.self).contains("serverInfo"))
    #expect(String(decoding: listData, as: UTF8.self).contains("tools"))
}

@Test
func parsesDateOnlyAndTimedValues() throws {
    let dateOnly = try DateParser.parse("2026-09-08", timeZone: TimeZone(secondsFromGMT: 0)!)
    #expect(dateOnly.dateOnly)

    let timed = try DateParser.parse("2026-09-08T14:30:00Z")
    #expect(!timed.dateOnly)
    #expect(timed.date.timeIntervalSince1970 == 1788877800)
}

@Test
func rejectsInvalidDates() {
    #expect(throws: GroveError.self) {
        try DateParser.parse("tomorrow afternoon")
    }
}

@Test
func exposesTheLeanInitialToolSurface() {
    #expect(ToolCatalog.tools.count == 12)
    #expect(ToolCatalog.tools.map(\.name).contains("create_event"))
    #expect(ToolCatalog.tools.map(\.name).contains("create_reminder"))

    let calendarTools = ToolCatalog.tools(for: [.calendar])
    #expect(calendarTools.count == 6)
    #expect(!calendarTools.map(\.name).contains("create_reminder"))
}
