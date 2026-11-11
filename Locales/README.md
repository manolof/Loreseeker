# Translating Loreseeker

Thank you! Each file here is one language (`deDE.lua` = German, `zhTW.lua` = Traditional Chinese, ...).

- Every line is `["English text"] = "your translation",`. Fill in the right-hand side.
- Leave `""` for anything you don't translate: English is shown instead, so a partial translation is fine.
- Keep `%s`, `%d`, `%+d`, `%%` placeholders (you may move them within the sentence) and colour codes like `|cffffd100 ... |r`.
- Quest, NPC, item and zone names are already in your language (they come from the game and QuestieDB), so you won't find them here. The only exception is the storyline section: its zone headings, storyline names and descriptions are Loreseeker's own.

Send your file as a pull request, or attach it to an issue at https://github.com/manolof/Loreseeker/issues.

Maintainers: after changing interface text or `Data/Storylines.lua`, run `node locales.js <addon dir>` from the dev tools; it adds new texts and keeps existing translations.
