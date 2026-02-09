local Addon = _G.Guidestone
local Localization = Addon.modules.Localization

---@class GuidestoneLinkPopup
local LinkPopup = {}
Addon.modules.LinkPopup = LinkPopup

local type = type
local tinsert = table.insert
local ceil = math.ceil
local CreateFrame = CreateFrame

LinkPopup.frame = nil

local function L(key, ...)
  return Localization:Get(key, ...)
end

local function EnsureFrame()
  if LinkPopup.frame then
    return LinkPopup.frame
  end

  local popup = CreateFrame("Frame", "GuidestoneLinkPopup", UIParent, "BackdropTemplate")
  popup:SetSize(640, 180)
  popup:SetFrameStrata("DIALOG")
  popup:SetClampedToScreen(true)
  popup:SetPoint("CENTER")
  popup:Hide()

  popup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })

  local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("Link")
  popup._title = title

  local desc = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  desc:SetPoint("TOP", title, "BOTTOM", 0, -8)
  desc:SetJustifyH("CENTER")
  desc:SetWidth(600)
  desc:SetText(L("LINKPOPUP_DESC"))
  popup._desc = desc

  -- Optional link buttons for multi-link materials.
  local links = CreateFrame("Frame", nil, popup)
  links:SetPoint("TOP", desc, "BOTTOM", 0, -6)
  links:SetWidth(600)
  links:SetHeight(1)
  links:Hide()
  popup._links = links

  popup._linkButtons = {}

  local function EnsureLinkButton(i)
    if popup._linkButtons[i] then
      return popup._linkButtons[i]
    end

    local btn = CreateFrame("Button", nil, links, "UIPanelButtonTemplate")
    btn:SetSize(280, 22)

    local col = (i % 2 == 1) and 0 or 1
    local row = math.floor((i - 1) / 2)

    btn:SetPoint("TOPLEFT", 10 + (col * 300), -(row * 24))

    popup._linkButtons[i] = btn
    return btn
  end

  -- Pre-create a small fixed set of link buttons.
  for i = 1, 8 do
    EnsureLinkButton(i)
  end

  local edit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
  edit:SetSize(580, 24)
  edit:SetPoint("TOP", links, "BOTTOM", 0, -10)
  edit:SetAutoFocus(true)
  edit:SetScript("OnEscapePressed", function()
    popup:Hide()
  end)
  edit:SetScript("OnEnterPressed", function()
    edit:HighlightText()
  end)
  popup._edit = edit

  local selectAll = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  selectAll:SetSize(120, 24)
  selectAll:SetText(L("LINKPOPUP_SELECT_ALL"))
  selectAll:SetPoint("BOTTOMLEFT", 18, 14)
  selectAll:SetScript("OnClick", function()
    edit:SetFocus()
    edit:HighlightText()
  end)
  popup._selectAll = selectAll

  local close = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  close:SetSize(120, 24)
  close:SetText(CLOSE)
  close:SetPoint("BOTTOMRIGHT", -18, 14)
  close:SetScript("OnClick", function()
    popup:Hide()
  end)
  popup._close = close

  -- Allow ESC to close.
  tinsert(UISpecialFrames, "GuidestoneLinkPopup")

  LinkPopup.frame = popup
  return popup
end

function LinkPopup:Show(titleText, url)
  local popup = EnsureFrame()

  if popup._links then
    popup._links:Hide()
  end
  if popup._linkButtons then
    for _, btn in ipairs(popup._linkButtons) do
      btn:Hide()
    end
  end
  popup:SetHeight(180)

  popup._title:SetText(titleText or L("LINKPOPUP_TITLE_LINK"))
  popup._edit:SetText(url or "")
  popup._edit:SetCursorPosition(0)
  popup._edit:SetFocus()
  popup._edit:HighlightText()

  popup:Show()
end

---Show multiple labeled links and let the player choose which one to copy.
---@param titleText string
---@param links table[] {title?:string, url:string}
function LinkPopup:ShowLinks(titleText, links)
  local popup = EnsureFrame()

  popup._title:SetText(titleText or L("LINKPOPUP_TITLE_LINKS"))

  local valid = {}
  if type(links) == "table" then
    for _, link in ipairs(links) do
      if type(link) == "table" and type(link.url) == "string" and link.url ~= "" then
        tinsert(valid, { title = link.title, url = link.url })
      end
    end
  end

  if #valid == 0 then
    popup._links:Hide()
    popup._edit:SetText("")
    popup:Show()
    return
  end

  popup._links:Show()

  -- Show up to 8 buttons (4 rows x 2 cols)
  local maxButtons = 8
  local shown = math.min(#valid, maxButtons)

  for i = 1, shown do
    local btn = popup._linkButtons[i]
    if not btn then
      break
    end

    local label = valid[i].title
    if type(label) ~= "string" or label == "" then
      label = ("Link %d"):format(i)
    end

    btn:SetText(label)
    btn:SetScript("OnClick", function()
      popup._edit:SetText(valid[i].url)
      popup._edit:SetCursorPosition(0)
      popup._edit:SetFocus()
      popup._edit:HighlightText()
    end)
    btn:Show()
  end

  for i = shown + 1, maxButtons do
    local btn = popup._linkButtons[i]
    if btn then
      btn:Hide()
    end
  end

  -- Resize link container height based on rows
  local rows = ceil(shown / 2)
  popup._links:SetHeight(rows * 24)

  -- Seed edit with first link
  popup._edit:SetText(valid[1].url)
  popup._edit:SetCursorPosition(0)
  popup._edit:SetFocus()
  popup._edit:HighlightText()

  -- Expand popup slightly for the button list
  local extra = rows * 24
  popup:SetHeight(180 + extra)

  popup:Show()
end

function LinkPopup:Hide()
  if self.frame then
    self.frame:Hide()
  end
end
