---
name: grove
description: Use Grove to read or manage Apple Calendar events and Reminders on macOS through its local MCP tools.
---

# Grove

Use Grove for requests that involve the user's Apple Calendar or Reminders.

## Before using tools

- Use Calendar tools for scheduled events and Reminders tools for tasks.
- If a Grove tool is unavailable, check the MCP connection and enabled services before asking the user to change settings.
- A sandbox can block localhost requests. Repeat a failed connection check with approved network access before reporting that Grove is offline.
- An HTTP 405 response to GET confirms only that the endpoint responds. Check an MCP initialize request and a read tool to confirm access.
- Use list tools to resolve calendar, list, event, or reminder identifiers. Do not guess identifiers.
- Use `YYYY-MM-DD` for date-only values. Use ISO 8601 with a time-zone offset for timed values.
- Calendar range end dates and reminder `dueTo` values are exclusive.

## Safe workflow

- Read before updating when the target or recurrence scope is not clear.
- Confirm the exact item before deletion.
- For recurring events, use `this_event` or `future_events` as requested. Ask when the intended scope is unclear.
- Preserve fields the user did not ask to change.
- After a create, update, completion, reopening, or deletion, report the affected item and relevant date or list.

## Scheduling details

- Weekly recurrence uses Sunday `1` through Saturday `7`.
- Use either a recurrence end date or an occurrence count.
- Alarm offsets use minutes relative to the event start or reminder due date. Negative values occur before it.
- Reminder priority is `0` for none and `1` through `9` for increasing priority.
