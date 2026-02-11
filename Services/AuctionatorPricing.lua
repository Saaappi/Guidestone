local Addon = _G.Guidestone

---@class GuidestoneAuctionatorPricing
local AuctionatorPricing = {}
Addon.modules.AuctionatorPricing = AuctionatorPricing

local type = type
local tonumber = tonumber
local floor = math.floor
local C_Item = C_Item
local C_CurrencyInfo = C_CurrencyInfo

---@return boolean
function AuctionatorPricing:IsAvailable()
  return type(_G.Auctionator) == "table"
    and type(_G.Auctionator.API) == "table"
    and type(_G.Auctionator.API.v1) == "table"
    and type(_G.Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

---@param itemID number|nil
---@return number|nil unitPriceCopper
function AuctionatorPricing:GetUnitPrice(itemID)
  itemID = tonumber(itemID)
  if not (itemID and itemID > 0) then
    return nil
  end

  if not self:IsAvailable() then
    return nil
  end

  local ok, price = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemID, Addon.name, itemID)
  if not ok then
    return nil
  end

  price = tonumber(price)
  if not (price and price >= 0) then
    return nil
  end

  return price
end

---@param copper number|nil
---@return string
function AuctionatorPricing:FormatMoney(copper)
  copper = tonumber(copper) or 0
  if copper < 0 then
    copper = 0
  end

  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    return C_CurrencyInfo.GetCoinTextureString(copper)
  end

  -- If C_CurrencyInfo.GetCoinTextureString is ever unavailable, let's have a manual fallback.
  local goldFloored = floor(copper / 10000)
  local silverFloored = floor((copper % 10000) / 100)
  local copperFloored = floor(copper % 100)
  return ("%dg %ds %dc"):format(goldFloored, silverFloored, copperFloored)
end

---@param terms string[]
---@return boolean started
function AuctionatorPricing:MultiSearch(terms)
  if not self:IsAvailable() then
    return false
  end

  if type(terms) ~= "table" or #terms == 0 then
    return false
  end

  if type(_G.Auctionator.API.v1.MultiSearch) ~= "function" then
    return false
  end

  local ok = pcall(_G.Auctionator.API.v1.MultiSearch, Addon.name, terms)
  return ok == true
end

---@param itemIDs number[]
---@return boolean started
function AuctionatorPricing:MultiSearchForItemIDs(itemIDs)
  if type(itemIDs) ~= "table" or #itemIDs == 0 then
    return false
  end

  -- Build search terms from item names.
  local terms = {}
  for _, rawID in ipairs(itemIDs) do
    local itemID = tonumber(rawID)
    if itemID and itemID > 0 then
      local name = nil
      if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
      end

      if (not name or name == "") and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(itemID)
      end

      if type(name) == "string" and name ~= "" then
        terms[#terms + 1] = name
      end
    end
  end

  return self:MultiSearch(terms)
end