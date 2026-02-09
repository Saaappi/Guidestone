local addonName = ...

---@class GuidestoneAddon
---@field name string
---@field db table|nil
---@field events Frame|nil
---@field modules table<string, table>
local Addon = {
  name = addonName,
  db = nil,
  events = nil,
  modules = {}
}

_G.Guidestone = Addon

---@return GuidestoneAddon
function Addon:Get()
  return self
end
