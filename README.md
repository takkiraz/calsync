# calsync

Mirrors the iCloud family calendar into the work Exchange calendar, so the work calendar shows "busy" when I have to take care of our child, and shows other family appointments as tentative until I decide. Runs locally on the Mac through macOS Calendar accounts (EventKit), no API keys, no cloud service.

## Prerequisites

- iCloud calendar sync enabled on this Mac (Calendar.app shows the family calendar).
- The work Exchange account added to Calendar.app with calendars enabled: System Settings > Internet Accounts > Microsoft Exchange. Events written there are normal Exchange events, so Outlook and the interview scheduling tool see them.
- Xcode (for `swiftc`).

## Rules

The `rules` list at the top of `calsync.swift` says how events from `sourceCalendar` are mirrored. The first matching rule wins, events matching no rule are ignored.

| Field | Meaning |
|---|---|
| `include` | Regex, case-insensitive, matched against the title (`.` means every event) |
| `exclude` | Regex or `nil`. Matching titles do not match this rule |
| `title` | Fixed title for the mirror, or `nil` to keep the original title |
| `availability` | `.busy` or `.tentative` for newly created mirrors |

Current rules:

1. Titles matching `dienst` (Frühdienst, Spätdienst, Nachtdienst) become "Kinderbetreuung", busy. Titles containing Oma, Opa, Omi, or Opi are skipped, so appending the name of whoever covers a shift removes the work block on the next run.
2. Every other event is mirrored with its original title as tentative. A shared iCloud calendar does not record who created an event, so this is where I decide.

All-day events (birthdays, holidays, vacation) are never mirrored. Other settings: `targetCalendar` and `horizonDays` (how far ahead to sync, from today).

## Deciding in Outlook

A tentative mirror is a question: does this family appointment concern me?

- Not mine: delete it in Outlook. It stays deleted, the tool remembers the event in `~/Library/Application Support/calsync/seen.json`.
- Mine: set it to Busy. The tool never touches availability of an existing mirror. Left as tentative, it depends on the interview tool whether that counts as free.

Title, start, and end of a mirror follow the family calendar; the tool overwrites them on change. A mirror whose source disappeared is deleted. If `seen.json` is lost, every rejected event comes back once as tentative.

## Usage

```sh
make list      # show Source/Calendar paths, grants calendar access on first run
make dry-run   # print create/update/delete without writing
make sync      # one real run
make deploy    # install the launch agent: runs sync once a day and at login
make undeploy  # unload the launch agent
```

Mirrored events carry `calsync:<id>` in their notes. That line is how the tool finds its own events, so leave it in place. Log: `~/Library/Logs/calsync.log`. A run without changes writes nothing.

## Calendar permission

The binary is ad-hoc signed, so every rebuild changes its identity and macOS asks for calendar access again. When run from the terminal the prompt is for the terminal app, when run by launchd it is for `calsync` itself. `make deploy` triggers the first launchd run immediately so the prompt appears while you are at the Mac.
