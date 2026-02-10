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
  print(Prefix(), tostring(msg), ...)
end

---@param msg any
---@param ... any
function Logger:Info(msg, ...)
  print(Prefix(), tostring(msg), ...)
end

---@param msg any
---@param ... any
function Logger:Warn(msg, ...)
  print(Prefix(), "|cffFFB020WARN|r", tostring(msg), ...)
end
