local _, ns = ...

ns.Util = ns.Util or {}

function ns.Util.SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return
  end

  local ok, err = pcall(fn, ...)
  if not ok then
    if ns.Logger and ns.Logger.Warn then
      ns.Logger:Warn("Error:", err)
    end
  end
end

function ns.Util.GetItemCount(itemID)
  if not itemID then
    return 0
  end

  -- Prefer C_Item on Retail. I'll add GetItemCount in case
  -- I choose to expand to Classic.
  if C_Item and C_Item.GetItemCount then
    -- includeBank = true; includeReagentsBank = true when supported
    local ok, count = pcall(C_Item.GetItemCount, itemID, true)
    if ok and type(count) == "number" then
      return count
    end
  end

  if _G.GetItemCount then
    local ok, count = pcall(_G.GetItemCount, itemID, true)
    if ok and type(count) == "number" then
      return count
    end
  end

  return 0
end

function ns.Util.GetWowheadItemUrl(itemID)
  return ("https://www.wowhead.com/item=%d"):format(tonumber(itemID) or 0)
end

function ns.Util.SetDesaturatedAndAlpha(region, desaturated, alpha)
  if region and region.SetDesaturated then
    region:SetDesaturated(desaturated and true or false)
  end

  if region and region.SetAlpha then
    region:SetAlpha(alpha or 1)
  end
end

function ns.Util.SetFontStringGreyed(fs, greyed)
  if not fs then
    return
  end

  if greyed then
    fs:SetTextColor(0.55, 0.55, 0.55, 1)
  else
    fs:SetTextColor(1, 1, 1, 1)
  end
end

-- -----------------------------------------------------------------------------
-- Waypoints / Navigation
-- -----------------------------------------------------------------------------

---@alias GuidestoneFactionFlag 0|1|2

---Returns the player's faction in the guide's flag foramt.
---0 = Neutral | 1 = Alliance | 2 = Horde
---@return GuidestoneFactionFlag
function ns.Util.GetPlayerFactionFlag()
  local faction = (UnitFactionGroup and UnitFactionGroup("player")) or nil
  if faction == "Alliance" then
    return 1
  elseif faction == "Horde" then
    return 2
  end

  return 0
end

---Whether TomTom is available and provides the AddWaypoint method.
---@return boolean
function ns.Util.IsTomTomAvailable()
  if not C_AddOns.IsAddOnLoaded then
    return false
  end

  if not C_AddOns.IsAddOnLoaded("TomTom") then
    return false
  end

  return type(_G.TomTom) == "table" and type(_G.TomTom.AddWaypoint) == "function"
end

---Add a waypoint to the player's map.
---If TomTom is enabled, this will add a TomTom waypoint.
---If TomTom is disabled, this will set a User Waypoint (super-tracked where possible).
---@param uiMapID number
---@param x number -- percent (0-100)
---@param y number -- percent (0-100)
---@param title string|nil
---@return boolean ok
function ns.Util.AddWaypoint(uiMapID, x, y, title)
  uiMapID = tonumber(uiMapID)
  x = tonumber(x)
  y = tonumber(y)

  if not (uiMapID and x and y) then
    return false
  end

  local nx = x / 100
  local ny = y / 100

  if ns.Util.IsTomTomAvailable() then
    local opts = {
      title = title or "Waypoint",
      persistent = false,
      minimap = true,
      world = true,
    }

    local ok = pcall(_G.TomTom.AddWaypoint, _G.TomTom, uiMapID, nx, ny, opts)
    return ok and true or false
  end

  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(uiMapID) then
      return false
    end

    local point = UiMapPoint.CreateFromCoordinates(uiMapID, nx, ny)
    local ok = pcall(C_Map.SetUserWaypoint, point)

    if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end

    return ok and true or false
  end

  return false
end