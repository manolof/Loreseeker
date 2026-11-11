# Lorewalker

**Do every quest worth doing.** A quest guide for **WoW Forever** for people who want to *see the world and its stories*, not race to max level, without giving up the streamlined "what next?" feel of a leveling guide.

Lorewalker is not a hand-written route. It reads the full quest database (via Questie), works out what *your* character can do right now, and plans a trip around it: picking up, doing and handing in quests in a sensible order, using the flight paths you know, boats and the tram.

## Features

- **Do (almost) everything:** every quest your character can do, grey ones included. Too-hard quests wait in a **Later** queue until you level up. You choose how far above your level counts as "too hard" (+1 to +10).
- **Plans ahead:** builds a trip of up to 16 steps, grouped into **stops**, so everything to pick up, do and hand in at one place happens together.
- **Real travel times:** routes by walking, flight paths you have discovered, boats, zeppelins and the Deeprun Tram. When flying is faster, the step panel says so and the arrow points at the flight master.
- **Lore first:** about 100 hand-picked notable storylines, grouped by zone with a short description each. They're given priority in the route. Star any other quest chain to treat it as notable too. Click any quest to see its whole storyline.
- **Lore journal:** saves the text of every quest you read, by zone. Quests done before you installed Lorewalker are filled in from Spoken's library, if Spoken is installed.
- **Listen:** plays Spoken's voice-over for a quest when available, and otherwise reads it with the game's built-in text-to-speech.
- **PvP-server friendly:** skip a quest, a whole storyline, the area around you, or a whole zone, each with a note and an optional "remind me at level N". A one-click preset covers the contested zones.
- **Smart items:** for each quest item it compares the drop rate, nearby vendors, the Auction House and your own recipes, and suggests the cheapest.
- **Copes with gaps in the data:** it spots breadcrumbs that are no longer offered, follow-up quests missing their prerequisite, and NPCs that don't offer a quest the database says they should.
- **Blizzard look:** stock frames, fonts and icons only.

## Requirements

- **WoW Forever** (interface 16001)
- **Questie** and **QuestieDB** (required)
- **Spoken** (optional, for voice-over)

## Commands

| Command | What it does |
|---|---|
| `/lw` | Open or close the window |
| `/lw plan` | Print the planned trip |
| `/lw travel` | Show which flight points it thinks you know |
| `/lw quest <id>` | Explain why a quest has its status |
| `/lw bug <text>` | Save a bug report with your situation (written to disk on `/reload`) |
| `/lw step`, `/lw arrow` | Show or hide the step panel or the arrow |
| `/lw rebuild` | Rebuild the quest index (normally automatic) |

## Bug reports and ideas

Please use [GitHub Issues](https://github.com/manolof/Lorewalker/issues). In game, type `/lw bug what happened`, then `/reload`, and attach `WTF/Account/<account>/SavedVariables/Lorewalker.lua` to the report.

## Privacy

Everything stays on your computer. Lorewalker sends nothing anywhere. Its diagnostics (errors and a short log of what it decided) are saved only in your own `SavedVariables`, to help with bug reports.

## Licence

GPLv3, see [LICENSE.md](LICENSE.md). Bundled libraries keep their own licences: LibStub, CallbackHandler-1.0 and HereBeDragons-2.0 (by Nevcairiel).
