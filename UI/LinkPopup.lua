local _, ns = ...

ns.LinkPopup = ns.LinkPopup or {}

local LinkPopup = ns.LinkPopup

LinkPopup.frame = nil

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
  desc:SetText("Copy the link below and paste it into your browser.")
  popup._desc = desc

  local edit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
  edit:SetSize(580, 24)
  edit:SetPoint("TOP", desc, "BOTTOM", 0, -10)
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
  selectAll:SetText("Select All")
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

  popup._title:SetText(titleText or "Link")
  popup._edit:SetText(url or "")
  popup._edit:SetCursorPosition(0)
  popup._edit:SetFocus()
  popup._edit:HighlightText()

  popup:Show()
end

function LinkPopup:Hide()
  if self.frame then
    self.frame:Hide()
  end
end
