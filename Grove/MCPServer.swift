import Foundation
import MCP

struct GroveServer {
    let store: EventKitStore
    let enabledServices: Set<GroveService>

    init(store: EventKitStore, enabledServices: Set<GroveService>) {
        self.store = store
        self.enabledServices = enabledServices
    }

    func run() async throws {
        let lease = try GroveProcessLease()
        defer { _ = lease }

        let server = Server(
            name: "grove",
            version: Grove.version,
            title: "Grove",
            capabilities: .init(tools: .init())
        )

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: ToolCatalog.tools(for: enabledServices))
        }

        await server.withMethodHandler(CallTool.self) { [store, enabledServices] (params: CallTool.Parameters) in
            do {
                guard let service = ToolCatalog.service(for: params.name), enabledServices.contains(service) else {
                    throw GroveError.serviceDisabled("The `\(params.name)` tool is disabled in Grove.")
                }
                let value = try await store.handle(params.name, arguments: params.arguments ?? [:])
                return try CallTool.Result(
                    content: [.text(text: jsonText(value), annotations: nil, _meta: nil)],
                    structuredContent: value
                )
            } catch {
                let message = error.localizedDescription
                let value: Value = .object(["error": .string(message)])
                return try CallTool.Result(
                    content: [.text(text: message, annotations: nil, _meta: nil)],
                    structuredContent: value,
                    isError: true
                )
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}

enum ToolCatalog {
    static let tools: [Tool] = [
        Tool(
            name: "list_calendars",
            description: "List writable and read-only Apple Calendar calendars.",
            inputSchema: schema(),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "list_events",
            description: "List Calendar events in a required date range.",
            inputSchema: schema(properties: [
                "startDate": string("Range start. ISO 8601 or YYYY-MM-DD."),
                "endDate": string("Range end. ISO 8601 or YYYY-MM-DD."),
                "calendarId": string("Optional calendar identifier."),
                "limit": integer("Maximum results, from 1 to 200. Defaults to 50.")
            ], required: ["startDate", "endDate"]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "get_event",
            description: "Fetch one Calendar event by identifier.",
            inputSchema: schema(properties: ["id": string("Event identifier.")], required: ["id"]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "create_event",
            description: "Create a Calendar event with optional recurrence and time alarms.",
            inputSchema: eventSchema(required: ["title", "startDate", "endDate"]),
            annotations: .init(destructiveHint: false, idempotentHint: false)
        ),
        Tool(
            name: "update_event",
            description: "Update a Calendar event. Use scope for recurring events.",
            inputSchema: eventSchema(properties: [
                "id": string("Event identifier."),
                "scope": scopeProperty()
            ], required: ["id"]),
            annotations: .init(destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "delete_event",
            description: "Delete a Calendar event. Use scope for recurring events.",
            inputSchema: schema(properties: [
                "id": string("Event identifier."),
                "scope": scopeProperty()
            ], required: ["id"]),
            annotations: .init(destructiveHint: true, idempotentHint: true)
        ),
        Tool(
            name: "list_reminder_lists",
            description: "List writable and read-only Apple Reminders lists.",
            inputSchema: schema(),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "list_reminders",
            description: "List Apple Reminders with status, list, due-date, and text filters.",
            inputSchema: schema(properties: [
                "status": enumString(["incomplete", "completed", "all"], "Reminder status. Defaults to incomplete."),
                "listId": string("Optional reminder-list identifier."),
                "dueFrom": string("Optional inclusive due-date range start for incomplete reminders."),
                "dueTo": string("Optional exclusive due-date range end for incomplete reminders."),
                "query": string("Optional text match against title and notes."),
                "limit": integer("Maximum results, from 1 to 200. Defaults to 50.")
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "get_reminder",
            description: "Fetch one Apple Reminder by identifier.",
            inputSchema: schema(properties: ["id": string("Reminder identifier.")], required: ["id"]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "create_reminder",
            description: "Create an Apple Reminder with optional due date, recurrence, and alarm.",
            inputSchema: reminderSchema(required: ["title"]),
            annotations: .init(destructiveHint: false, idempotentHint: false)
        ),
        Tool(
            name: "update_reminder",
            description: "Update an Apple Reminder. Use completed to complete or reopen it.",
            inputSchema: reminderSchema(properties: ["id": string("Reminder identifier.")], required: ["id"]),
            annotations: .init(destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "delete_reminder",
            description: "Delete an Apple Reminder.",
            inputSchema: schema(properties: ["id": string("Reminder identifier.")], required: ["id"]),
            annotations: .init(destructiveHint: true, idempotentHint: true)
        )
    ]

    static func tools(for enabledServices: Set<GroveService>) -> [Tool] {
        tools.filter { tool in
            guard let service = service(for: tool.name) else { return false }
            return enabledServices.contains(service)
        }
    }

    static func service(for toolName: String) -> GroveService? {
        GroveService.allCases.first { $0.toolNames.contains(toolName) }
    }

    private static func schema(properties: [String: Value] = [:], required: [String] = []) -> Value {
        var value: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty {
            value["required"] = .array(required.map(Value.string))
        }
        return .object(value)
    }

    private static func eventSchema(
        properties extra: [String: Value] = [:],
        required: [String] = []
    ) -> Value {
        var properties: [String: Value] = [
            "title": string("Event title."),
            "startDate": string("ISO 8601 timestamp or YYYY-MM-DD."),
            "endDate": string("ISO 8601 timestamp or YYYY-MM-DD."),
            "calendarId": string("Optional writable calendar identifier."),
            "allDay": boolean("Whether this is an all-day event."),
            "location": string("Optional location."),
            "notes": string("Optional notes."),
            "url": string("Optional URL."),
            "timeZone": string("Optional IANA time-zone identifier."),
            "recurrence": recurrenceProperty(),
            "alarms": alarmsProperty()
        ]
        properties.merge(extra) { _, new in new }
        return schema(properties: properties, required: required)
    }

    private static func reminderSchema(
        properties extra: [String: Value] = [:],
        required: [String] = []
    ) -> Value {
        var properties: [String: Value] = [
            "title": string("Reminder title."),
            "listId": string("Optional writable reminder-list identifier."),
            "notes": string("Optional notes."),
            "priority": integer("Priority from 0 (none) to 9."),
            "completed": boolean("Whether the reminder is complete."),
            "startDate": string("Optional ISO 8601 timestamp or YYYY-MM-DD."),
            "dueDate": string("Optional ISO 8601 timestamp or YYYY-MM-DD."),
            "recurrence": recurrenceProperty(),
            "alarms": alarmsProperty()
        ]
        properties.merge(extra) { _, new in new }
        return schema(properties: properties, required: required)
    }

    private static func recurrenceProperty() -> Value {
        .object([
            "type": .string("object"),
            "description": .string("Common recurring schedule."),
            "properties": .object([
                "frequency": enumString(["daily", "weekly", "monthly", "yearly"], "Repeat unit."),
                "interval": integer("Repeat every N units. Defaults to 1."),
                "weekdays": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("integer"), "minimum": .int(1), "maximum": .int(7)]),
                    "description": .string("Weekly days: Sunday=1 through Saturday=7.")
                ]),
                "endDate": string("Optional recurrence end date."),
                "count": integer("Optional occurrence count.")
            ]),
            "required": .array([.string("frequency")]),
            "additionalProperties": .bool(false)
        ])
    }

    private static func alarmsProperty() -> Value {
        .object([
            "type": .string("array"),
            "items": .object([
                "type": .string("object"),
                "properties": .object([
                    "absoluteDate": string("Absolute ISO 8601 alarm time."),
                    "relativeMinutes": number("Minutes relative to the item start." )
                ]),
                "additionalProperties": .bool(false)
            ])
        ])
    }

    private static func scopeProperty() -> Value {
        enumString(["this_event", "future_events"], "Scope for a recurring event change.")
    }

    private static func string(_ description: String) -> Value {
        .object(["type": .string("string"), "description": .string(description)])
    }

    private static func integer(_ description: String) -> Value {
        .object(["type": .string("integer"), "description": .string(description)])
    }

    private static func number(_ description: String) -> Value {
        .object(["type": .string("number"), "description": .string(description)])
    }

    private static func boolean(_ description: String) -> Value {
        .object(["type": .string("boolean"), "description": .string(description)])
    }

    private static func enumString(_ values: [String], _ description: String) -> Value {
        .object([
            "type": .string("string"),
            "enum": .array(values.map(Value.string)),
            "description": .string(description)
        ])
    }
}
