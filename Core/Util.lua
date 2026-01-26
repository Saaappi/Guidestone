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
