-- Translations. Every piece of interface text goes through LW.L["English text"].
-- English is the key itself, so a missing translation simply shows English: a partial
-- translation can never break anything. Translations live in Locales\<locale>.lua and only
-- the one matching the client is applied (see Locales\README.md).
local _, LW = ...

LW.locale = GetLocale and GetLocale() or "enUS"

LW.L = setmetatable({}, {
  __index = function(_, key) return key end,
})

-- English zone name -> area ID, so zone names can come from the game in the client's language.
LW.ZONE_IDS = {
  ["Elwynn Forest"] = 12, ["Dun Morogh"] = 1, ["Loch Modan"] = 38, ["Westfall"] = 40, ["Redridge Mountains"] = 44,
  ["Duskwood"] = 10, ["Wetlands"] = 11, ["Arathi Highlands"] = 45, ["Hillsbrad Foothills"] = 267,
  ["Alterac Mountains"] = 36, ["Stranglethorn Vale"] = 33, ["Swamp of Sorrows"] = 8, ["Badlands"] = 3,
  ["Searing Gorge"] = 51, ["Burning Steppes"] = 46, ["Blasted Lands"] = 4, ["Western Plaguelands"] = 28,
  ["Eastern Plaguelands"] = 139, ["The Hinterlands"] = 47, ["Darkshore"] = 148, ["Ashenvale"] = 331,
  ["Stonetalon Mountains"] = 406, ["The Barrens"] = 17, ["Desolace"] = 405, ["Dustwallow Marsh"] = 15,
  ["Thousand Needles"] = 400, ["Tanaris"] = 440, ["Feralas"] = 357, ["Un'Goro Crater"] = 490, ["Azshara"] = 16,
  ["Felwood"] = 361, ["Winterspring"] = 618, ["Silithus"] = 1377,
}

--- A zone's name in the client's language (falls back to the translation table, then English).
function LW.LocalZone(english)
  local id = LW.ZONE_IDS[english]
  local name = id and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
  if name and name ~= "" then return name end
  return LW.L[english]
end

--- Called by each Locales\xxXX.lua file. Only the client's own language is applied.
function LW:AddTranslations(locale, strings)
  if locale ~= self.locale then return end
  for english, translated in pairs(strings) do
    if type(translated) == "string" and translated ~= "" then rawset(self.L, english, translated) end
  end
end
