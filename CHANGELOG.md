# Changelog

## 0.2.1
- First release on CurseForge (no gameplay changes from 0.2.0)

## 0.2.0
- Renamed from "Lorewalker" (another addon already uses that name). The command is now `/lore` (`/lw` still works); saved data is carried over
- Item objectives weigh every source (drop rate, vendor, Auction House, your recipes) and show the cheapest
- Recipes learned from your profession window
- Quest index cached per character; rebuilt automatically when Questie, QuestieDB, Loreseeker or your skills change
- Lookahead planner (up to 16 steps), grouped into stops ("on the way")
- Travel model: known flight paths, boats, zeppelins, Deeprun Tram
- About 100 curated storylines grouped by zone; star your own
- Breadcrumb and missing-prerequisite detection; "NPC doesn't offer this" checks
- Map libraries bundled (no hidden dependency on other addons)
- Quests that only the other faction's NPCs give are no longer listed

## 0.1.0
- First version: dynamic routing, skips with notes, Later queue, storylines, lore journal, Spoken voice-over, diagnostics
