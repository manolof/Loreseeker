-- Translations. Every piece of interface text goes through LW.L["English text"].
-- English is the key itself, so a missing translation simply shows English: a partial
-- translation can never break anything. Translations live in Locales\<locale>.lua and only
-- the one matching the client is applied (see Locales\README.md).
local _, LW = ...

LW.locale = GetLocale and GetLocale() or "enUS"

LW.L = setmetatable({}, {
  __index = function(_, key) return key end,
})

--- Called by each Locales\xxXX.lua file. Only the client's own language is applied.
function LW:AddTranslations(locale, strings)
  if locale ~= self.locale then return end
  for english, translated in pairs(strings) do
    if type(translated) == "string" and translated ~= "" then rawset(self.L, english, translated) end
  end
end
