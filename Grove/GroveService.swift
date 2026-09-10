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
        case .reminders: return "list.bullet"
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

enum GrovePreferences {
    static let suiteName = "com.thsnkhn.grove.settings"
    private static let welcomeCompletedKey = "welcome.completed"

    // UserDefaults synchronizes its own reads and writes across processes.
    nonisolated(unsafe) private static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    static func isEnabled(_ service: GroveService) -> Bool {
        defaults.object(forKey: service.preferenceKey) != nil &&
            defaults.bool(forKey: service.preferenceKey)
    }

    static func setEnabled(_ enabled: Bool, for service: GroveService) {
        guard isEnabled(service) != enabled else { return }
        defaults.set(enabled, forKey: service.preferenceKey)
        DistributedNotificationCenter.default.post(
            name: .groveServicesDidChange,
            object: suiteName
        )
    }

    static func enabledServices() -> Set<GroveService> {
        Set(GroveService.allCases.filter(isEnabled))
    }

    static func hasCompletedWelcome() -> Bool {
        defaults.bool(forKey: welcomeCompletedKey)
    }

    static func setWelcomeCompleted(_ completed: Bool) {
        defaults.set(completed, forKey: welcomeCompletedKey)
    }
}

extension Notification.Name {
    static let groveServicesDidChange = Notification.Name("GroveServicesDidChange")
}
