local Addon = _G.Guidestone

---@class GuidestoneLocalization
local Localization = {
  locales = {},
  strings = {},
  locale = "enUS"
}
Addon.modules.Localization = Localization

local format = string.format

---@param locale string
---@param strings table<string, string>
function Localization:RegisterLocale(locale, strings)
  if type(locale) ~= "string" or locale == "" then
    return
  end

  if type(strings) ~= "table" then
    return
  end

  self.locales[locale] = strings
end

function Localization:Init()
  local locale = "enUS"
  if type(GetLocale) == "function" then
    locale = GetLocale() or "enUS"
  end

  self.locale = locale

  local chosen = self.locales[locale]
  local fallback = self.locales["enUS"]

  self.strings = chosen or fallback or {}
end

---@param key string
---@param ... any
---@return string
function Localization:Get(key, ...)
  if type(key) ~= "string" or key == "" then
    return ""
  end

  local active = self.strings and self.strings[key]
  local fallback = self.locales["enUS"] and self.locales["enUS"][key]

  local text = active or fallback or key

  if select("#", ...) > 0 then
    return format(text, ...)
  end

  return text
end