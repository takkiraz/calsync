# Decisions

## 2026-11-05: Local EventKit sync instead of Graph API or ICS subscription

An ICS subscription of the iCloud calendar in Outlook does not count towards Exchange free/busy, so the interview scheduling tool would still see me as available. The Microsoft Graph API needs an app registration in the work tenant and a headless token refresh that Conditional Access can break. EventKit uses the accounts already configured in macOS Calendar, needs no credentials, and writes real Exchange events. Cost: the Mac has to be awake, which is fine because shifts are planned weeks ahead.

## 2026-11-05: Keyword filter with an exclude convention

Only titles matching `dienst` are mirrored. When somebody else takes the day, the family event gets the name appended, for example `(Oma)`, and the mirror is removed on the next run. This keeps the information visible to both of us in the family calendar instead of hiding it in a local state file.

## 2026-11-05: Fixed title "Kinderbetreuung", original title in notes

Colleagues see why I am blocked without my partner's shift names appearing in the work calendar. The original title is kept in the notes next to the `calsync:` marker.

## 2026-11-05: Mirror wins over manual edits (superseded below)

The tool overwrites a mirrored event whenever it differs from the source and deletes mirrors without a source. Edits belong in the family calendar, not in Outlook.

## 2026-11-05: No creator information, so everything else is mirrored as tentative

EventKit exposes no creator for events in a shared iCloud calendar: organizer and attendees are empty, and Calendar's database is not readable. So "my entries" cannot be filtered out of Familie, and moving them to another calendar is out because my partner has to see them. Instead every timed family event that is not a shift is mirrored as tentative with its original title, and I decide in Outlook.

## 2026-11-05: Decisions in Outlook stick, remembered in a state file

Deleting a tentative mirror in Outlook must not bring it back on the next run, and setting one to busy must not be reverted. The tool therefore keeps the keys of all mirrors it ever created in `~/Library/Application Support/calsync/seen.json`, skips sources whose key is known but whose mirror is gone, and never writes availability to an existing mirror. Title, start, and end still follow the family calendar. This supersedes "mirror wins over manual edits" for deletion and availability.

## 2026-11-05: Events from other people are ignored

The default iCloud calendar on this Mac is Familie, so any invitation I receive shows up there before I accept it. Mirroring it would let a stranger place events into my work calendar, including busy blocks when the title contains "dienst". Only events without an organizer, organized by me, or accepted by me are mirrored. The same check applies when looking for mirrors in the Exchange calendar, and the marker is read from its last occurrence, so neither a title containing "calsync:" nor a meeting invite with it in the body can pass as a mirror. Titles are stripped of control characters before logging.

## 2026-11-05: All-day events are skipped

The first dry run of the Privat rule picked up a birthday, which would have blocked a whole work day as busy. All-day entries in my calendars are birthdays, holidays, or vacation, and vacation reaches the work calendar through HR. Skipping them is one condition and avoids leaking private all-day entries into the work calendar.
