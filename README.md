# Guild Utilities

Guild management utilities for WoW Classic Era (1.15.x) and WoW Forever.

## Install

Copy this folder to `World of Warcraft\_classic_era_\Interface\AddOns\GuildUtilities`.

## Modules

- **Roster** - remembers when members joined, reports joins/leaves, and adds join dates to the guild member tooltip.
- **Bank** - snapshots the bank character's bags into `Guild_Bank`.
- **Loot Tracker** - logs every item looted by anyone in your group, so you can check that gathered or
  disenchanted materials (Core Leather, Dark Iron Ore, shards, ...) make it to the guild bank.

## Loot Tracker

`/loottracker` opens the window. Other commands: `start`, `stop`, `fav [item link]`, `help`.

- A session starts when a group forms and is stashed when it disbands; use `<` / `>` to browse
  past sessions (or "All sessions"). Hover the session name for its start/stop times and members.
- **Start** (`/loottracker start`) stashes the current session and records a new one, with or without
  a group. It keeps running through group changes until **Stop** (`/loottracker stop`).
- **Log** lists every pickup; **Totals** groups by item and player, with a **Per hour** average over
  the time that player was in the session(s). It updates live while recording.
- Click a column header to sort, click again to reverse. Filter by player, item, minimum quality
  or favorites only.
- Click the star to favorite an item; favorites are pinned to the top (toggle in the footer).
- Right-click a row to filter by that player, shift-click to link the item in chat.
- **Export CSV** opens the current view as CSV text to copy.

Only loot your client sees is recorded, i.e. "X receives loot" messages while you're in range.

## Layout

```
Core.lua                 namespace, event dispatch, callbacks, API compatibility
Util.lua                 shared helpers (names, strings, time, CSV, format-string parsing)
UI/Widgets.lua           reusable widgets (window, buttons, inputs, sortable table, copy dialog)
Modules/Bank.lua
Modules/Roster.lua
Modules/LootTracker/     Parser, Sessions, Query, UI
```
