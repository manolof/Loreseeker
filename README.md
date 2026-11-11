<p align="center">
  <img src="media/logo-400.png" alt="Loreseeker" width="160" height="160">
</p>

<h1 align="center">Loreseeker</h1>

<p align="center">
  <b>Do every quest worth doing.</b><br>
  A lore-first quest guide for <b>WoW Forever</b>: every quest and story, in a smart order.
</p>

<p align="center">
  <a href="https://github.com/manolof/Loreseeker/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/manolof/Loreseeker?label=release&color=e3b34c"></a>
  <a href="https://www.curseforge.com/wow/addons/loreseeker"><img alt="CurseForge downloads" src="https://img.shields.io/curseforge/dt/1798150?label=CurseForge&logo=curseforge&color=f16436"></a>
  <img alt="WoW Forever" src="https://img.shields.io/badge/WoW-Forever%201.60-2b3d6b">
  <br>
  <a href="https://github.com/manolof/Loreseeker/actions/workflows/check.yml"><img alt="Check" src="https://github.com/manolof/Loreseeker/actions/workflows/check.yml/badge.svg"></a>
  <a href="https://github.com/manolof/Loreseeker/actions/workflows/release.yml"><img alt="Release build" src="https://github.com/manolof/Loreseeker/actions/workflows/release.yml/badge.svg"></a>
  <a href="LICENSE.md"><img alt="License: GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue"></a>
  <img alt="Languages" src="https://img.shields.io/badge/languages-EN%20DE%20FR%20ES%20RU%20ZH-6c4f2a">
  <a href="https://github.com/manolof/Loreseeker/issues"><img alt="Open issues" src="https://img.shields.io/github/issues/manolof/Loreseeker?color=8a5a17"></a>
</p>

---

Loreseeker is for players who want to **see the world and its stories**, not race to max level, without giving up the streamlined *"what next?"* feel of a leveling guide.

It isn't a hand-written route. Loreseeker reads the full quest database (via Questie), works out what **your** character can do right now, and plans a trip around it: picking up, doing and handing in quests in a sensible order, using the flight paths you know, boats and the tram.

## ✨ Features

| | |
|---|---|
| 📜 **Do (almost) everything** | Every quest your character can do, grey ones included. Too-hard quests wait in a **Later** queue until you level up, and you choose what "too hard" means (+1 to +10 levels). |
| 🧭 **Plans your trip** | Up to 16 steps ahead, grouped into **stops**, so everything to pick up, do and hand in at one place happens together. |
| 🪽 **Real travel** | Walking, the flight paths *you* have discovered, boats, zeppelins and the Deeprun Tram. When flying is faster, the arrow points at the flight master. |
| 📖 **Lore first** | About 100 hand-picked storylines, grouped by zone and given priority in the route. Star any other chain you like, and click any quest to see its whole storyline. |
| 🖋️ **Lore journal** | Saves the text of every quest you read, so you can reread the story later. |
| 🔊 **Listen** | Plays Spoken's voice-over when it's installed, and otherwise reads the quest with the game's text-to-speech. |
| ⚔️ **PvP-server friendly** | Skip a quest, a storyline, the area around you or a whole zone, with a note and an optional *"remind me at level 40"*. A one-click preset covers the contested zones. |
| 💰 **Smart items** | Compares drop rates, nearby vendors, the Auction House and your own recipes, and suggests the cheapest. |
| 🔍 **Copes with gaps in the data** | Spots breadcrumbs that are no longer offered, follow-ups missing their prerequisite, and NPCs that don't offer what the database says. |
| 🎨 **Looks like the game** | Stock Blizzard frames, fonts and icons, with no custom skins. Works on every client language, including Chinese, Korean and Russian. |

## 📦 Install

1. Install **Questie** (it includes QuestieDB). Optionally install **Spoken** for voice-over.
2. Install **Loreseeker** from [CurseForge](https://www.curseforge.com/wow/addons/loreseeker) or [GitHub Releases](https://github.com/manolof/Loreseeker/releases/latest).
3. Log in and type `/lore`.

## ⌨️ Commands

| Command | What it does |
|---|---|
| `/lore` | Open or close the window |
| `/lore plan` | Print the planned trip |
| `/lore travel` | Show which flight points it thinks you know |
| `/lore quest <id>` | Explain why a quest has its status |
| `/lore bug <text>` | Save a bug report with your situation (written to disk on `/reload`) |
| `/lore step`, `/lore arrow` | Show or hide the step panel or the arrow |
| `/lore rebuild` | Rebuild the quest index (normally automatic) |

## 🌍 Languages

English, German, French, Spanish, Russian and Simplified Chinese. Quest, NPC, item and zone names always appear in your client's language, because they come from the game. Other languages fall back to English for Loreseeker's own text.

**Want to help translate?** See [Locales/README.md](Locales/README.md). A partial translation is fine.

## 🐞 Bug reports and ideas

Please use [GitHub Issues](https://github.com/manolof/Loreseeker/issues). In game, type `/lore bug what happened`, then `/reload`, and attach `WTF/Account/<account>/SavedVariables/Loreseeker.lua` to the report.

## 🔒 Privacy

Everything stays on your computer: Loreseeker sends nothing anywhere. Its diagnostics (errors and a short log of what it decided) are saved only in your own `SavedVariables`, to help with bug reports.

## 📄 Licence

GPLv3, see [LICENSE.md](LICENSE.md). Bundled libraries keep their own licences: LibStub, CallbackHandler-1.0 and HereBeDragons-2.0 (by Nevcairiel).
