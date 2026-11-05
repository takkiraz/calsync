import EventKit
import Foundation

struct Rule {
    let include: String
    let exclude: String?
    let title: String?
    let availability: EKEventAvailability
}

let sourceCalendar = "iCloud/Familie"
let targetCalendar = "Exchange/Kalender"
let rules = [
    Rule(include: "dienst", exclude: "Oma|Opa|Omi|Opi", title: "Kinderbetreuung", availability: .busy),
    Rule(include: ".", exclude: "dienst", title: nil, availability: .tentative),
]
let horizonDays = 90
let marker = "calsync:"
let stateFile = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/calsync/seen.json")

let store = EKEventStore()
let mode = CommandLine.arguments.dropFirst().first ?? "dry-run"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func must(_ action: () throws -> Void) {
    do { try action() } catch { fail("\(error)") }
}

func requestAccess() {
    let semaphore = DispatchSemaphore(value: 0)
    var granted = false
    store.requestFullAccessToEvents { ok, _ in
        granted = ok
        semaphore.signal()
    }
    semaphore.wait()
    if !granted { fail("no calendar access, allow calsync under System Settings > Privacy & Security > Calendars") }
}

func calendar(named path: String) -> EKCalendar {
    guard let found = store.calendars(for: .event).first(where: { "\($0.source.title)/\($0.title)" == path }) else {
        fail("calendar \(path) not found, run: calsync list")
    }
    return found
}

func matches(_ pattern: String?, _ text: String) -> Bool {
    guard let pattern else { return false }
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

func trusted(_ event: EKEvent) -> Bool {
    guard let organizer = event.organizer, !organizer.isCurrentUser else { return true }
    return event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .accepted } ?? false
}

func clean(_ text: String) -> String {
    String(text.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
}

func rule(for event: EKEvent) -> Rule? {
    guard !event.isAllDay, trusted(event) else { return nil }
    let title = event.title ?? ""
    return rules.first { matches($0.include, title) && !matches($0.exclude, title) }
}

func key(of event: EKEvent) -> String {
    let base = event.calendarItemIdentifier
    guard event.hasRecurrenceRules || event.isDetached, let occurrence = event.occurrenceDate else { return base }
    return "\(base)@\(Int(occurrence.timeIntervalSince1970))"
}

func mirroredKey(of event: EKEvent) -> String? {
    guard trusted(event), !event.hasAttendees, let notes = event.notes,
          let range = notes.range(of: marker, options: .backwards) else { return nil }
    let key = String(notes[range.upperBound...].prefix { !$0.isWhitespace })
    return key.isEmpty ? nil : key
}

requestAccess()

if mode == "list" {
    for calendar in store.calendars(for: .event) {
        print("\(calendar.source.title)/\(calendar.title)" + (calendar.allowsContentModifications ? "" : " (read-only)"))
    }
    exit(0)
}

let dryRun = mode != "sync"
let source = calendar(named: sourceCalendar)
let target = calendar(named: targetCalendar)
let start = Calendar.current.startOfDay(for: Date())
let end = Calendar.current.date(byAdding: .day, value: horizonDays, to: start)!
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd HH:mm"

var seen = Set((try? JSONDecoder().decode([String].self, from: Data(contentsOf: stateFile))) ?? [])
var existing: [String: EKEvent] = [:]
for event in store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: [target])) {
    if let key = mirroredKey(of: event) { existing[key] = event }
}
seen.formUnion(existing.keys)

var current: Set<String> = []
for event in store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: [source])) {
    guard let rule = rule(for: event) else { continue }
    let key = key(of: event)
    current.insert(key)
    let title = rule.title ?? event.title ?? ""
    let mirror = existing.removeValue(forKey: key)
    if mirror == nil && seen.contains(key) { continue }
    if let mirror, mirror.startDate == event.startDate, mirror.endDate == event.endDate, mirror.title == title { continue }
    let action = mirror == nil ? "create\(rule.availability == .tentative ? " tentative" : "")" : "update"
    print("\(action) \(formatter.string(from: event.startDate))-\(formatter.string(from: event.endDate).suffix(5)) \(clean(event.title ?? ""))")
    if dryRun { continue }
    let item = mirror ?? EKEvent(eventStore: store)
    if mirror == nil {
        item.calendar = target
        item.availability = rule.availability
        item.alarms = nil
        item.notes = "\(event.title ?? "")\n\(marker)\(key)"
        seen.insert(key)
    }
    item.title = title
    item.startDate = event.startDate
    item.endDate = event.endDate
    must { try store.save(item, span: .thisEvent, commit: false) }
}
for orphan in existing.values {
    print("delete \(formatter.string(from: orphan.startDate)) \(clean(orphan.notes?.components(separatedBy: "\n").first ?? ""))")
    if dryRun { continue }
    must { try store.remove(orphan, span: .thisEvent, commit: false) }
}
if dryRun { exit(0) }
must { try store.commit() }
seen.formIntersection(current)
must {
    try FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(seen.sorted()).write(to: stateFile)
}
