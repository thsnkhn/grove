import Foundation
import MCP

enum GroveError: LocalizedError, Sendable {
    case invalidArgument(String)
    case missingArgument(String)
    case invalidDate(String)
    case invalidScheduling(String)
    case notFound(String)
    case permission(String)
    case eventKit(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message), .missingArgument(let message), .invalidDate(let message),
             .invalidScheduling(let message), .notFound(let message), .permission(let message),
             .eventKit(let message):
            return message
        }
    }
}

struct RecurrenceInput: Codable, Sendable {
    let frequency: String
    let interval: Int?
    let weekdays: [Int]?
    let endDate: String?
    let count: Int?
}

struct AlarmInput: Codable, Sendable {
    let absoluteDate: String?
    let relativeMinutes: Double?
}

struct DateValue: Sendable {
    let date: Date
    let dateOnly: Bool
    let timeZone: TimeZone
}

enum DateParser {
    static func parse(_ value: String, timeZone: TimeZone = .current) throws -> DateValue {
        if value.count == 10, let date = dateOnly(value, timeZone: timeZone) {
            return DateValue(date: date, dateOnly: true, timeZone: timeZone)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return DateValue(date: date, dateOnly: false, timeZone: timeZone)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return DateValue(date: date, dateOnly: false, timeZone: timeZone)
        }

        throw GroveError.invalidDate("Invalid date `\(value)`. Use YYYY-MM-DD or ISO 8601.")
    }

    static func format(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func format(_ components: DateComponents?, timeZone: TimeZone = .current) -> String? {
        guard let components, let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = components.timeZone ?? timeZone

        if let date = calendar.date(from: components) {
            if components.hour == nil {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
            return format(date, timeZone: calendar.timeZone)
        }
        return nil
    }

    static func reminderComponents(_ value: String, timeZone: TimeZone = .current) throws -> DateComponents {
        let parsed = try parse(value, timeZone: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var components = calendar.dateComponents(
            parsed.dateOnly ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute, .second],
            from: parsed.date
        )
        components.calendar = calendar
        components.timeZone = parsed.dateOnly ? nil : timeZone
        return components
    }

    private static func dateOnly(_ value: String, timeZone: TimeZone) -> Date? {
        let pieces = value.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2]))
    }
}

enum Arguments {
    static func requiredString(_ values: [String: Value], _ key: String) throws -> String {
        guard let value = values[key]?.stringValue, !value.isEmpty else {
            throw GroveError.missingArgument("Missing required argument `\(key)`.")
        }
        return value
    }

    static func string(_ values: [String: Value], _ key: String) -> String? {
        values[key]?.stringValue
    }

    static func bool(_ values: [String: Value], _ key: String) -> Bool? {
        values[key]?.boolValue
    }

    static func int(_ values: [String: Value], _ key: String) -> Int? {
        values[key]?.intValue
    }

    static func double(_ values: [String: Value], _ key: String) -> Double? {
        if let value = values[key]?.doubleValue { return value }
        return values[key]?.intValue.map(Double.init)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ values: [String: Value], _ key: String) throws -> T? {
        guard let value = values[key], !value.isNull else { return nil }
        do {
            let data = try JSONEncoder().encode(value)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GroveError.invalidArgument("Invalid argument `\(key)`: \(error.localizedDescription)")
        }
    }

    static func has(_ values: [String: Value], _ key: String) -> Bool {
        values[key] != nil
    }
}

func jsonText(_ value: Value) -> String {
    guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else {
        return value.description
    }
    return text
}
