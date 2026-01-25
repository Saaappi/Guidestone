local _, ns = ...

ns.Logger = ns.Logger or {}

local function Prefix()
  return "|cff9AD6FFGuidestone|r"
end

function ns.Logger:Debug(...)
  if not (GuidestoneDB and GuidestoneDB.debug) then
    return
  end

  print(Prefix(), ...)
end

function ns.Logger:Info(...)
  print(Prefix(), ...)
end

function ns.Logger.Warn(...)
  print(Prefix(), "|cffFFB020WARN|r", ...)
end
