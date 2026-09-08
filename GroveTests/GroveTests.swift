import Foundation
import Testing
@testable import Grove

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
}
