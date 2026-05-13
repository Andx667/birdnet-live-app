# Session Library

Session Library is the archive of saved sessions and processed files.

## How to Open It

Use the :material-music-box-multiple-outline: button in the Home footer.

## What the Library Shows

Each session entry summarizes a saved result set, including its type, date, duration, species count, and detection count.

Session types use the same icons as the Home screen:

- :material-microphone: — Live session
- :material-file-music: — File Analysis session
- :material-map-marker: — Point Count session
- :material-routes: — Survey session

## App Bar Controls

- :material-magnify: — search by date, session type, place name, coordinates, common name, or scientific name
- view-mode menu — switch between **Detailed**, **Compact**, and **By Species**
- :material-swap-vertical: — change the sort order

## View Modes

### Detailed

Shows full session cards with more metadata.

### Compact

Shows tighter rows for faster browsing. Each row has a :material-chevron-down: button on the right that expands the row in place to the full Detailed-view card body — handy when you want a quick stats peek at one specific session without losing your scroll position.

### By Species

Groups sessions by species and expands to the sessions that contain that species.

## Sorting

Sort sessions by **date** (newest or oldest first), **name** (A–Z or Z–A), or **duration** (longest or shortest first). Duration sort is useful when you want to find your longest survey of the week, or the shortest 30-second test you accidentally saved.

When sessions are grouped by day, each day-header row shows the kebab (:material-dots-vertical:) for whole-day actions first, with the expand/collapse chevron at the trailing edge of the row. The chevron is the *last* affordance — same convention as every other expandable list in the app — so a tap near the right edge always toggles the group.

## Local Time

Every timestamp shown in Session Library — list rows, day-group headers, "started" / "ended" badges — is rendered in your phone's *current* local time zone. The session's underlying timestamps are stored in UTC, so a session you ran in Berlin and then opened in New York simply renders five (or six) hours earlier — the data on disk is unchanged. Travel during a long survey and the displayed clock follows the device.

## Row Actions

Each session row has two ways to act on it:

- **Three-dot menu** (:material-dots-vertical:) on the right of every card opens a small menu with **Open**, **Share**, and **Delete**. Share uses your current Settings → Export preferences (format and "include audio") and opens the platform share sheet directly — no need to first open Session Review just to send a session to a colleague.
- **Swipe** the row left or right to delete it. A confirmation dialog still appears before anything is removed, so an accidental swipe is recoverable.

## What Happens Next

Tap any session to open [Session Review](session-review.md).