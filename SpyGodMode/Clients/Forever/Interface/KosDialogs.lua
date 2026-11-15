local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local K={}; SGM:RegisterModule("KosDialogs",K)

local function clean(text)
 text=tostring(text or ""):gsub("^%s+",""):gsub("%s+$","")
 return text
end

function K:Add(name,reason)
 name=SGM:ShortName(name)
 reason=clean(reason)
 if not name or name=="" then return false end
 if reason=="" then
  SGM:Print(L["A Kill On Sight reason is required for "]..name..L["."])
  return false
 end
 SGM.modules.Roster:SetKos(name,reason)
 SGM:SafeSound("ADD")
 SGM:Print(name..L[" added to Kill On Sight: "]..reason)
 return true
end

local function createDialog()
 if K.dialog then return K.dialog end

 local f=CreateFrame("Frame","SpyGodModeKosReasonDialog",UIParent,"BackdropTemplate")
 f:SetSize(430,175)
 f:SetPoint("CENTER")
 f:SetFrameStrata("DIALOG")
 f:SetToplevel(true)
 f:SetClampedToScreen(true)
 f:EnableMouse(true)
 f:SetMovable(true)
 f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(self) self:StartMoving() end)
 f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
 f:Hide()

 if f.SetBackdrop then
  f:SetBackdrop({
   bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
   edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
   tile=true,tileSize=32,edgeSize=32,
   insets={left=11,right=12,top=12,bottom=11},
  })
 end

 local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
 title:SetPoint("TOP",0,-22)
 f.title=title

 local prompt=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 prompt:SetPoint("TOPLEFT",30,-55)
 prompt:SetText(L["Enter a reason:"])

 local box=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
 box:SetPoint("TOPLEFT",30,-78)
 box:SetPoint("TOPRIGHT",-30,-78)
 box:SetHeight(28)
 box:SetAutoFocus(false)
 box:SetNumeric(false)
 box:SetMaxLetters(255)
 if box.SetMaxBytes then box:SetMaxBytes(1024) end
 box:SetScript("OnEscapePressed",function() f:Hide() end)
 f.editBox=box

 local save=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
 save:SetSize(110,24)
 save:SetPoint("BOTTOMRIGHT",-120,22)
 f.saveButton=save

 local cancel=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
 cancel:SetSize(90,24)
 cancel:SetPoint("LEFT",save,"RIGHT",10,0)
 cancel:SetText(CANCEL or L["Cancel"])
 cancel:SetScript("OnClick",function() f:Hide() end)

 local function saveReason()
  local name=f.playerName
  local reason=box:GetText() or ""
  local wasEdit=f.isEdit
  if K:Add(name,reason) then
   if wasEdit then SGM:Print("Kill On Sight reason updated for "..name) end
   f:Hide()
  else
   box:SetFocus()
  end
 end
 save:SetScript("OnClick",saveReason)
 box:SetScript("OnEnterPressed",saveReason)

 f:SetScript("OnShow",function()
  box:SetFocus()
 end)

 if UISpecialFrames then table.insert(UISpecialFrames,"SpyGodModeKosReasonDialog") end
 K.dialog=f
 return f
end

function K:Prompt(name,edit)
 name=SGM:ShortName(name)
 if not name or name=="" then return end
 local f=createDialog()
 f.playerName=name
 f.isEdit=not not edit
 f.title:SetText(edit and ("Edit Kill On Sight reason for "..name) or ("Add "..name.." to Kill On Sight"))
 f.saveButton:SetText(edit and L["Save"] or L["Add to KoS"])
 local entry=SGM.db.kos[name]
 f.editBox:SetText(edit and entry and entry.reason or "")
 f:Show()
 f:Raise()
 f.editBox:SetFocus()
 if edit then f.editBox:HighlightText() else f.editBox:SetCursorPosition(0) end
end

function K:Remove(name)
 name=SGM:ShortName(name)
 if not name or not SGM.db.kos[name] then return end
 SGM.modules.Roster:RemoveKos(name)
 SGM:SafeSound("REMOVE")
 SGM:Print(name..L[" removed from Kill On Sight"])
end
