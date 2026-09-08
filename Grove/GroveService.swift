import Foundation

enum GroveService: String, CaseIterable, Hashable, Identifiable, Sendable {
    case calendar
    case reminders

    var id: Self { self }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        }
    }

    var outlineSymbolName: String {
        switch self {
        case .calendar: return "calendar"
        case .reminders: return "list.bullet"
        }
    }

    var filledSymbolName: String {
        switch self {
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        }
    }

    var preferenceKey: String {
        "service.\(rawValue).enabled"
    }

    var toolNames: Set<String> {
        switch self {
        case .calendar:
            return [
                "list_calendars",
                "list_events",
                "get_event",
                "create_event",
                "update_event",
                "delete_event"
            ]
        case .reminders:
            return [
                "list_reminder_lists",
                "list_reminders",
                "get_reminder",
                "create_reminder",
                "update_reminder",
                "delete_reminder"
            ]
        }
    }
}

@MainActor
enum GrovePreferences {
    static let suiteName = "com.thsnkhn.grove.settings"

    private static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    static func isEnabled(_ service: GroveService) -> Bool {
        defaults.object(forKey: service.preferenceKey) != nil &&
            defaults.bool(forKey: service.preferenceKey)
    }

    static func setEnabled(_ enabled: Bool, for service: GroveService) {
        defaults.set(enabled, forKey: service.preferenceKey)
    }

    static func enabledServices() -> Set<GroveService> {
        Set(GroveService.allCases.filter(isEnabled))
    }
}
