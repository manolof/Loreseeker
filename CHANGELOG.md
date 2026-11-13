# Changelog

## Unreleased
- Fixed: 182 quests were hidden (a database flag for "completed by a scripted event", like escorts, was mistaken for "seasonal event"), including The Defias Brotherhood, Missing In Action and The Algaz Gauntlet
- Fixed: quests ready to hand in were sometimes not recognised as complete (now: all objectives done, or no objectives), so their turn-ins were never routed
- Quests whose objectives have no known location point at their turn-in NPC instead of having no location
- Dungeon quests the game tags as such stay off the main route even after you pick them up (listed under Group up)
- Routing pauses while you're on a flight path and while you're dead; when dead, the arrow points to your corpse
- Hearthstone: learned when you set it at an innkeeper, and used for routing when it's off cooldown
- Undiscovered flight points near your quests become optional steps (at most two at a time); new ones are announced and used for routing right away

## 0.3.0
- Translated into German, French, Spanish, Russian and Simplified Chinese (more languages welcome, see Locales/README.md)
- Works on every client language: storylines are matched by quest ID, the flight map is read by position, and zone and storyline names come from the game where possible
- Buttons and the step panel grow to fit longer words in other languages
- New command name /lore (/lw still works)
- On-screen notifications when Loreseeker decides something by itself (e.g. an NPC doesn't offer a quest); can be turned off in Options
- /lore probe: shows what the game tells addons about your target

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
