@preconcurrency import EventKit
import Foundation
import MCP

private struct ReminderBox: @unchecked Sendable {
    let values: [EKReminder]
}

@MainActor
final class EventKitStore {
    private let eventStore = EKEventStore()
    private let timeZone = TimeZone.current

    func authorize() async throws -> String {
        let events = try await authorize(.calendar)
        let reminders = try await authorize(.reminders)
        return "Calendar: \(events ? "granted" : "denied")\nReminders: \(reminders ? "granted" : "denied")"
    }

    func authorize(_ service: GroveService) async throws -> Bool {
        switch service {
        case .calendar:
            return try await requestEventsAccess()
        case .reminders:
            return try await requestRemindersAccess()
        }
    }

    func doctor() -> String {
        let calendarStatus = status(for: .event)
        let reminderStatus = status(for: .reminder)
        return """
        Grove \(Grove.version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        time zone: \(timeZone.identifier)
        Calendar access: \(calendarStatus)
        Reminders access: \(reminderStatus)
        """
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> Value {
        switch name {
        case "list_calendars": return try listCalendars()
        case "list_events": return try listEvents(arguments)
        case "get_event": return try getEvent(arguments)
        case "create_event": return try createEvent(arguments)
        case "update_event": return try updateEvent(arguments)
        case "delete_event": return try deleteEvent(arguments)
        case "list_reminder_lists": return try listReminderLists()
        case "list_reminders": return try await listReminders(arguments)
        case "get_reminder": return try getReminder(arguments)
        case "create_reminder": return try createReminder(arguments)
        case "update_reminder": return try updateReminder(arguments)
        case "delete_reminder": return try deleteReminder(arguments)
        default: throw GroveError.invalidArgument("Unknown tool `\(name)`.")
        }
    }

    private func listCalendars() throws -> Value {
        try requireFullAccess(for: .event)
        let calendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return .object(["calendars": .array(calendars.map(calendarValue))])
    }

    private func listEvents(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .event)
        let start = try parsedDate(arguments, key: "startDate")
        let end = try parsedDate(arguments, key: "endDate")
        guard start.date < end.date else {
            throw GroveError.invalidArgument("`startDate` must be before `endDate`.")
        }

        let calendars: [EKCalendar]?
        if let calendarID = Arguments.string(arguments, "calendarId") {
            calendars = [try eventCalendar(calendarID)]
        } else {
            calendars = nil
        }

        let events = eventStore.events(
            matching: eventStore.predicateForEvents(
                withStart: start.date,
                end: end.date,
                calendars: calendars
            )
        ).sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }

        let limit = try limit(arguments)
        let selected = Array(events.prefix(limit))
        return .object([
            "events": .array(selected.map(eventValue)),
            "truncated": .bool(events.count > limit)
        ])
    }

    private func getEvent(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .event)
        let id = try Arguments.requiredString(arguments, "id")
        guard let event = eventStore.event(withIdentifier: id) else {
            throw GroveError.notFound("Event `\(id)` was not found.")
        }
        return eventValue(event)
    }

    private func createEvent(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .event)
        let title = try Arguments.requiredString(arguments, "title")
        let start = try parsedDate(arguments, key: "startDate")
        let end = try parsedDate(arguments, key: "endDate")
        guard start.date < end.date else {
            throw GroveError.invalidArgument("`startDate` must be before `endDate`.")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start.date
        event.endDate = end.date
        event.isAllDay = Arguments.bool(arguments, "allDay") ?? (start.dateOnly && end.dateOnly)
        event.calendar = try targetEventCalendar(arguments)
        try applyEventFields(event, arguments: arguments, creating: true)
        try eventStore.save(event, span: .thisEvent)
        return eventValue(event)
    }

    private func updateEvent(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .event)
        let id = try Arguments.requiredString(arguments, "id")
        guard let event = eventStore.event(withIdentifier: id) else {
            throw GroveError.notFound("Event `\(id)` was not found.")
        }

        if Arguments.has(arguments, "title") {
            event.title = try nullableString(arguments, "title") ?? ""
        }
        if Arguments.has(arguments, "startDate") {
            event.startDate = try nullableDate(arguments, "startDate")
        }
        if Arguments.has(arguments, "endDate") {
            event.endDate = try nullableDate(arguments, "endDate")
        }
        if Arguments.has(arguments, "allDay") {
            guard let allDay = Arguments.bool(arguments, "allDay") else {
                throw GroveError.invalidArgument("`allDay` must be a boolean.")
            }
            event.isAllDay = allDay
        }
        if Arguments.has(arguments, "calendarId") {
            event.calendar = try eventCalendar(Arguments.requiredString(arguments, "calendarId"))
        }
        try applyEventFields(event, arguments: arguments, creating: false)
        try validateEventDates(event)
        try eventStore.save(event, span: try eventSpan(arguments))
        return eventValue(event)
    }

    private func deleteEvent(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .event)
        let id = try Arguments.requiredString(arguments, "id")
        guard let event = eventStore.event(withIdentifier: id) else {
            throw GroveError.notFound("Event `\(id)` was not found.")
        }
        try eventStore.remove(event, span: try eventSpan(arguments))
        return .object(["deleted": .bool(true), "id": .string(id)])
    }

    private func listReminderLists() throws -> Value {
        try requireFullAccess(for: .reminder)
        let lists = eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return .object(["lists": .array(lists.map(calendarValue))])
    }

    private func listReminders(_ arguments: [String: Value]) async throws -> Value {
        try requireFullAccess(for: .reminder)
        let status = (Arguments.string(arguments, "status") ?? "incomplete").lowercased()
        guard ["incomplete", "completed", "all"].contains(status) else {
            throw GroveError.invalidArgument("`status` must be incomplete, completed, or all.")
        }

        let calendars = try reminderCalendars(arguments)
        let dueFrom = try optionalParsedDate(arguments, key: "dueFrom")
        let dueTo = try optionalParsedDate(arguments, key: "dueTo")
        if status == "completed", dueFrom != nil || dueTo != nil {
            throw GroveError.invalidArgument("`dueFrom` and `dueTo` apply to incomplete reminders.")
        }
        if let dueFrom, let dueTo, dueFrom.date >= dueTo.date {
            throw GroveError.invalidArgument("`dueFrom` must be before `dueTo`.")
        }

        let predicate: NSPredicate
        switch status {
        case "completed":
            predicate = eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: nil,
                ending: nil,
                calendars: calendars
            )
        case "all":
            predicate = eventStore.predicateForReminders(in: calendars)
        default:
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: dueFrom?.date,
                ending: dueTo?.date,
                calendars: calendars
            )
        }

        let reminders = try await fetchReminders(matching: predicate)
            .filter { reminder in
                let matchesDueRange: Bool = {
                    guard status == "all", dueFrom != nil || dueTo != nil else { return true }
                    guard let due = reminder.dueDateComponents,
                          let date = Calendar(identifier: .gregorian).date(from: due) else { return false }
                    if let dueFrom, date < dueFrom.date { return false }
                    if let dueTo, date >= dueTo.date { return false }
                    return true
                }()
                guard matchesDueRange else { return false }

                guard let query = Arguments.string(arguments, "query"), !query.isEmpty else { return true }
                let haystack = "\(reminder.title ?? "") \(reminder.notes ?? "")".localizedLowercase
                return haystack.contains(query.localizedLowercase)
            }
            .sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }

        let limit = try limit(arguments)
        let selected = Array(reminders.prefix(limit))
        return .object([
            "reminders": .array(selected.map(reminderValue)),
            "truncated": .bool(reminders.count > limit)
        ])
    }

    private func getReminder(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .reminder)
        let id = try Arguments.requiredString(arguments, "id")
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw GroveError.notFound("Reminder `\(id)` was not found.")
        }
        return reminderValue(reminder)
    }

    private func createReminder(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .reminder)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = try Arguments.requiredString(arguments, "title")
        reminder.calendar = try targetReminderCalendar(arguments)
        try applyReminderFields(reminder, arguments: arguments, creating: true)
        try eventStore.save(reminder, commit: true)
        return reminderValue(reminder)
    }

    private func updateReminder(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .reminder)
        let id = try Arguments.requiredString(arguments, "id")
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw GroveError.notFound("Reminder `\(id)` was not found.")
        }
        if Arguments.has(arguments, "title") {
            reminder.title = try nullableString(arguments, "title") ?? ""
        }
        if Arguments.has(arguments, "listId") {
            reminder.calendar = try reminderCalendar(Arguments.requiredString(arguments, "listId"))
        }
        try applyReminderFields(reminder, arguments: arguments, creating: false)
        try eventStore.save(reminder, commit: true)
        return reminderValue(reminder)
    }

    private func deleteReminder(_ arguments: [String: Value]) throws -> Value {
        try requireFullAccess(for: .reminder)
        let id = try Arguments.requiredString(arguments, "id")
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw GroveError.notFound("Reminder `\(id)` was not found.")
        }
        try eventStore.remove(reminder, commit: true)
        return .object(["deleted": .bool(true), "id": .string(id)])
    }

    private func applyEventFields(_ event: EKEvent, arguments: [String: Value], creating: Bool) throws {
        if creating || Arguments.has(arguments, "location") {
            event.location = try nullableString(arguments, "location")
        }
        if creating || Arguments.has(arguments, "notes") {
            event.notes = try nullableString(arguments, "notes")
        }
        if creating || Arguments.has(arguments, "url") {
            event.url = try nullableURL(arguments, "url")
        }
        if creating || Arguments.has(arguments, "timeZone") {
            if let value = try nullableString(arguments, "timeZone") {
                guard let timeZone = TimeZone(identifier: value) else {
                    throw GroveError.invalidArgument("Unknown time zone `\(value)`.")
                }
                event.timeZone = timeZone
            } else {
                event.timeZone = nil
            }
        }
        if creating || Arguments.has(arguments, "recurrence") {
            event.recurrenceRules = try recurrenceRules(arguments, key: "recurrence")
        }
        if creating || Arguments.has(arguments, "alarms") {
            event.alarms = try alarms(arguments, key: "alarms", timeZone: try requestedTimeZone(arguments))
        }
    }

    private func applyReminderFields(_ reminder: EKReminder, arguments: [String: Value], creating: Bool) throws {
        if creating || Arguments.has(arguments, "notes") {
            reminder.notes = try nullableString(arguments, "notes")
        }
        if creating || Arguments.has(arguments, "priority") {
            guard let priority = Arguments.int(arguments, "priority") ?? (creating ? 0 : nil), (0...9).contains(priority) else {
                throw GroveError.invalidArgument("`priority` must be an integer from 0 to 9.")
            }
            reminder.priority = priority
        }
        if creating || Arguments.has(arguments, "completed") {
            guard let completed = Arguments.bool(arguments, "completed") ?? (creating ? false : nil) else {
                throw GroveError.invalidArgument("`completed` must be a boolean.")
            }
            reminder.isCompleted = completed
        }
        if creating || Arguments.has(arguments, "startDate") {
            reminder.startDateComponents = try nullableReminderDate(arguments, key: "startDate")
        }
        if creating || Arguments.has(arguments, "dueDate") {
            reminder.dueDateComponents = try nullableReminderDate(arguments, key: "dueDate")
        }
        if creating || Arguments.has(arguments, "recurrence") {
            reminder.recurrenceRules = try recurrenceRules(arguments, key: "recurrence")
        }
        if creating || Arguments.has(arguments, "alarms") {
            let inputs: [AlarmInput] = try Arguments.decode([AlarmInput].self, arguments, "alarms") ?? []
            if inputs.contains(where: { $0.relativeMinutes != nil }),
               reminder.dueDateComponents?.hour == nil,
               reminder.startDateComponents?.hour == nil {
                throw GroveError.invalidScheduling("Relative reminder alarms need a timed due or start date.")
            }
            reminder.alarms = try alarms(arguments, key: "alarms", timeZone: timeZone)
        }
    }

    private func targetEventCalendar(_ arguments: [String: Value]) throws -> EKCalendar {
        if let id = Arguments.string(arguments, "calendarId") {
            return try eventCalendar(id)
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw GroveError.eventKit("No default writable Calendar calendar is available.")
        }
        return calendar
    }

    private func targetReminderCalendar(_ arguments: [String: Value]) throws -> EKCalendar {
        if let id = Arguments.string(arguments, "listId") {
            return try reminderCalendar(id)
        }
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw GroveError.eventKit("No default writable Reminders list is available.")
        }
        return calendar
    }

    private func eventCalendar(_ id: String) throws -> EKCalendar {
        guard let calendar = eventStore.calendar(withIdentifier: id), calendar.allowedEntityTypes.contains(.event) else {
            throw GroveError.notFound("Calendar `\(id)` was not found.")
        }
        guard calendar.allowsContentModifications else {
            throw GroveError.permission("Calendar `\(calendar.title)` is read-only.")
        }
        return calendar
    }

    private func reminderCalendar(_ id: String) throws -> EKCalendar {
        guard let calendar = eventStore.calendar(withIdentifier: id), calendar.allowedEntityTypes.contains(.reminder) else {
            throw GroveError.notFound("Reminder list `\(id)` was not found.")
        }
        guard calendar.allowsContentModifications else {
            throw GroveError.permission("Reminder list `\(calendar.title)` is read-only.")
        }
        return calendar
    }

    private func reminderCalendars(_ arguments: [String: Value]) throws -> [EKCalendar]? {
        guard let id = Arguments.string(arguments, "listId") else { return nil }
        return [try reminderCalendar(id)]
    }

    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        let box: ReminderBox = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: ReminderBox(values: reminders ?? []))
            }
        }
        return box.values
    }

    private func parsedDate(_ arguments: [String: Value], key: String) throws -> DateValue {
        guard let value = Arguments.string(arguments, key) else {
            throw GroveError.missingArgument("Missing required argument `\(key)`.")
        }
        return try DateParser.parse(value, timeZone: requestedTimeZone(arguments))
    }

    private func optionalParsedDate(_ arguments: [String: Value], key: String) throws -> DateValue? {
        guard let value = Arguments.string(arguments, key) else { return nil }
        return try DateParser.parse(value, timeZone: timeZone)
    }

    private func nullableDate(_ arguments: [String: Value], _ key: String) throws -> Date? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let string = value.stringValue else {
            throw GroveError.invalidArgument("`\(key)` must be a date string or null.")
        }
        return try DateParser.parse(string, timeZone: requestedTimeZone(arguments)).date
    }

    private func nullableReminderDate(_ arguments: [String: Value], key: String) throws -> DateComponents? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let string = value.stringValue else {
            throw GroveError.invalidArgument("`\(key)` must be a date string or null.")
        }
        return try DateParser.reminderComponents(string, timeZone: timeZone)
    }

    private func nullableString(_ arguments: [String: Value], _ key: String) throws -> String? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let string = value.stringValue else {
            throw GroveError.invalidArgument("`\(key)` must be a string or null.")
        }
        return string
    }

    private func nullableURL(_ arguments: [String: Value], _ key: String) throws -> URL? {
        guard let string = try nullableString(arguments, key) else { return nil }
        guard let url = URL(string: string) else {
            throw GroveError.invalidArgument("`\(key)` is not a valid URL.")
        }
        return url
    }

    private func limit(_ arguments: [String: Value]) throws -> Int {
        let value = Arguments.int(arguments, "limit") ?? 50
        guard (1...200).contains(value) else {
            throw GroveError.invalidArgument("`limit` must be between 1 and 200.")
        }
        return value
    }

    private func eventSpan(_ arguments: [String: Value]) throws -> EKSpan {
        switch (Arguments.string(arguments, "scope") ?? "this_event").lowercased() {
        case "this_event": return .thisEvent
        case "future_events": return .futureEvents
        default: throw GroveError.invalidArgument("`scope` must be this_event or future_events.")
        }
    }

    private func recurrenceRules(_ arguments: [String: Value], key: String) throws -> [EKRecurrenceRule]? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let input: RecurrenceInput = try Arguments.decode(RecurrenceInput.self, arguments, key) else { return nil }
        return [try recurrenceRule(input, timeZone: requestedTimeZone(arguments))]
    }

    private func recurrenceRule(_ input: RecurrenceInput, timeZone: TimeZone) throws -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch input.frequency.lowercased() {
        case "daily": frequency = .daily
        case "weekly": frequency = .weekly
        case "monthly": frequency = .monthly
        case "yearly": frequency = .yearly
        default: throw GroveError.invalidScheduling("Unsupported recurrence frequency `\(input.frequency)`.")
        }

        let interval = input.interval ?? 1
        guard interval > 0 else { throw GroveError.invalidScheduling("Recurrence interval must be greater than zero.") }
        if input.weekdays != nil, frequency != .weekly {
            throw GroveError.invalidScheduling("`weekdays` is supported for weekly recurrence only.")
        }
        if input.endDate != nil && input.count != nil {
            throw GroveError.invalidScheduling("Use either `endDate` or `count`, not both.")
        }

        let days: [EKRecurrenceDayOfWeek]?
        if let weekdays = input.weekdays {
            guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }) else {
                throw GroveError.invalidScheduling("Weekly `weekdays` values must be integers from 1 (Sunday) to 7 (Saturday).")
            }
            days = weekdays.map { EKRecurrenceDayOfWeek(dayOfTheWeek: EKWeekday(rawValue: $0)!, weekNumber: 0) }
        } else {
            days = nil
        }

        let end: EKRecurrenceEnd?
        if let endDate = input.endDate {
            end = EKRecurrenceEnd(end: try DateParser.parse(endDate, timeZone: timeZone).date)
        } else if let count = input.count {
            guard count > 0 else { throw GroveError.invalidScheduling("Recurrence count must be greater than zero.") }
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else {
            end = nil
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: days,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    private func alarms(_ arguments: [String: Value], key: String, timeZone: TimeZone) throws -> [EKAlarm]? {
        guard let value = arguments[key], !value.isNull else { return nil }
        guard let inputs: [AlarmInput] = try Arguments.decode([AlarmInput].self, arguments, key) else { return nil }
        return try inputs.map { input in
            if let absoluteDate = input.absoluteDate {
                if input.relativeMinutes != nil {
                    throw GroveError.invalidScheduling("An alarm cannot use both `absoluteDate` and `relativeMinutes`.")
                }
                return EKAlarm(absoluteDate: try DateParser.parse(absoluteDate, timeZone: timeZone).date)
            }
            if let relativeMinutes = input.relativeMinutes {
                return EKAlarm(relativeOffset: relativeMinutes * 60)
            }
            throw GroveError.invalidScheduling("Each alarm needs `absoluteDate` or `relativeMinutes`.")
        }
    }

    private func requestedTimeZone(_ arguments: [String: Value]) throws -> TimeZone {
        guard let identifier = Arguments.string(arguments, "timeZone") else { return timeZone }
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw GroveError.invalidArgument("Unknown time zone `\(identifier)`.")
        }
        return timeZone
    }

    private func validateEventDates(_ event: EKEvent) throws {
        guard let start = event.startDate, let end = event.endDate, start < end else {
            throw GroveError.invalidArgument("`startDate` must be before `endDate`.")
        }
    }

    private func requireFullAccess(for entityType: EKEntityType) throws {
        guard EKEventStore.authorizationStatus(for: entityType).rawValue == 3 else {
            let label = entityType == .event ? "Calendar" : "Reminders"
            throw GroveError.permission("Full \(label) access is required. Run `grove authorize` and allow access in System Settings.")
        }
    }

    private func status(for entityType: EKEntityType) -> String {
        switch EKEventStore.authorizationStatus(for: entityType).rawValue {
        case 0: return "not determined"
        case 1: return "restricted"
        case 2: return "denied"
        case 3: return "full access"
        case 4: return "write only"
        default: return "unknown"
        }
    }

    private func requestEventsAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    private func requestRemindersAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    private func calendarValue(_ calendar: EKCalendar) -> Value {
        .object([
            "id": .string(calendar.calendarIdentifier),
            "title": .string(calendar.title),
            "allowsContentModifications": .bool(calendar.allowsContentModifications),
            "source": .string(calendar.source?.title ?? "")
        ])
    }

    private func eventValue(_ event: EKEvent) -> Value {
        var value: [String: Value] = [
            "id": .string(event.eventIdentifier ?? event.calendarItemIdentifier),
            "title": .string(event.title),
            "calendarId": .string(event.calendar.calendarIdentifier),
            "calendar": .string(event.calendar.title),
            "allDay": .bool(event.isAllDay),
            "recurrence": recurrenceValue(event),
            "alarms": alarmsValue(event.alarms)
        ]
        if let startDate = event.startDate { value["startDate"] = .string(DateParser.format(startDate, timeZone: event.timeZone ?? timeZone)) }
        if let endDate = event.endDate { value["endDate"] = .string(DateParser.format(endDate, timeZone: event.timeZone ?? timeZone)) }
        if let location = event.location { value["location"] = .string(location) }
        if let notes = event.notes { value["notes"] = .string(notes) }
        if let url = event.url { value["url"] = .string(url.absoluteString) }
        if let timeZone = event.timeZone { value["timeZone"] = .string(timeZone.identifier) }
        if let occurrenceDate = event.occurrenceDate { value["occurrenceDate"] = .string(DateParser.format(occurrenceDate, timeZone: event.timeZone ?? timeZone)) }
        return .object(value)
    }

    private func reminderValue(_ reminder: EKReminder) -> Value {
        var value: [String: Value] = [
            "id": .string(reminder.calendarItemIdentifier),
            "title": .string(reminder.title),
            "listId": .string(reminder.calendar.calendarIdentifier),
            "list": .string(reminder.calendar.title),
            "completed": .bool(reminder.isCompleted),
            "priority": .int(Int(reminder.priority)),
            "recurrence": recurrenceValue(reminder),
            "alarms": alarmsValue(reminder.alarms)
        ]
        if let notes = reminder.notes { value["notes"] = .string(notes) }
        if let dueDate = DateParser.format(reminder.dueDateComponents, timeZone: timeZone) { value["dueDate"] = .string(dueDate) }
        if let startDate = DateParser.format(reminder.startDateComponents, timeZone: timeZone) { value["startDate"] = .string(startDate) }
        if let completionDate = reminder.completionDate { value["completionDate"] = .string(DateParser.format(completionDate, timeZone: timeZone)) }
        return .object(value)
    }

    private func alarmsValue(_ alarms: [EKAlarm]?) -> Value {
        .array((alarms ?? []).map { alarm in
            if let date = alarm.absoluteDate {
                return .object(["absoluteDate": .string(DateParser.format(date, timeZone: timeZone))])
            }
            return .object(["relativeMinutes": .double(alarm.relativeOffset / 60)])
        })
    }

    private func recurrenceValue(_ item: EKCalendarItem) -> Value {
        guard let rule = item.recurrenceRules?.first else { return .null }

        let frequency: String
        switch rule.frequency {
        case .daily: frequency = "daily"
        case .weekly: frequency = "weekly"
        case .monthly: frequency = "monthly"
        case .yearly: frequency = "yearly"
        @unknown default: frequency = "unknown"
        }

        var value: [String: Value] = [
            "frequency": .string(frequency),
            "interval": .int(rule.interval)
        ]
        if let weekdays = rule.daysOfTheWeek {
            value["weekdays"] = .array(weekdays.map { .int($0.dayOfTheWeek.rawValue) })
        }
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                value["endDate"] = .string(DateParser.format(endDate, timeZone: timeZone))
            } else if end.occurrenceCount > 0 {
                value["count"] = .int(end.occurrenceCount)
            }
        }
        return .object(value)
    }
}
