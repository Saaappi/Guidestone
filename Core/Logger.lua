local Addon = _G.Guidestone

local tostring = tostring
local format = string.format

---@class GuidestoneLogger
local Logger = {}

Addon.modules.Logger = Logger

local function Prefix()
  return format("|cff9AD6FF%s|r:", Addon.name or "Guidestone")
end

---@return boolean
function Logger:IsDebugEnabled()
  local db = Addon.db
  return (db and db.debug) == true
end

---@param msg any
---@param ... any
function Logger:Debug(msg, ...)
  if not self:IsDebugEnabled() then
    return
  end
  msg = tostring(msg)
  print(Prefix(), format(msg, ...))
end

---@param msg any
---@param ... any
function Logger:Info(msg, ...)
  msg = tostring(msg)
  print(Prefix(), format(msg, ...))
end

---@param msg any
---@param ... any
function Logger:Warn(msg, ...)
  msg = tostring(msg)
  print(Prefix(), "|cffFFB020WARN|r", format(msg, ...))
end
