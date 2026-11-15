local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local A={}; SGM:RegisterModule("AlertFrame",A)

local CLASS_TEXTURE="Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local fallbackCoords={
 WARRIOR={0,0.25,0,0.25},MAGE={0.25,0.49609375,0,0.25},ROGUE={0.49609375,0.7421875,0,0.25},DRUID={0.7421875,0.98828125,0,0.25},
 HUNTER={0,0.25,0.25,0.5},SHAMAN={0.25,0.49609375,0.25,0.5},PRIEST={0.49609375,0.7421875,0.25,0.5},WARLOCK={0.7421875,0.98828125,0.25,0.5},
 PALADIN={0,0.25,0.5,0.75}
}

local function setClassIcon(texture,class)
 local coords=(CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or fallbackCoords[class]
 if not coords then return false end
 texture:SetTexture(CLASS_TEXTURE)
 texture:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
 return true
end

local function setAlertIcon(kind,p)
 A.icon:SetTexCoord(0,1,0,1)
 if kind=="STEALTH" then
  -- Show the actual stealth source whenever possible.
  if p.class=="ROGUE" and setClassIcon(A.icon,"ROGUE") then return end
  if p.class=="DRUID" and setClassIcon(A.icon,"DRUID") then return end
  if p.stealthSpellId==58984 or p.race=="NightElf" or p.race=="Night Elf" then
   local tex=SGM:GetSpellTexture(58984)
   if tex then A.icon:SetTexture(tex); return end
  end
  if p.class and setClassIcon(A.icon,p.class) then return end
 end
 if kind==L["KOS"] or kind=="HIGH" or kind=="TARGET" or kind=="SOS" then
  A.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
 elseif p.class and setClassIcon(A.icon,p.class) then
  return
 else
  A.icon:SetTexture("Interface\\Icons\\Ability_Spy")
 end
end

function A:Create()
 local f=CreateFrame("Frame","SpyGodMode_AlertFrame",UIParent,"BackdropTemplate"); f:SetSize(300,48); f:SetPoint("TOP",UIParent,"TOP",SGM.cfg.alertX,SGM.cfg.alertY); SGM:Backdrop(f,{.85,.08,.02,1}); f:Hide(); self.frame=f
 local icon=f:CreateTexture(nil,"ARTWORK"); icon:SetSize(34,34); icon:SetPoint("LEFT",7,0); icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"); self.icon=icon
 self.head=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.head:SetPoint("TOPLEFT",48,-7); self.head:SetTextColor(1,.3,.1)
 self.name=f:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge"); self.name:SetPoint("TOPLEFT",48,-21); self.zone=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); self.zone:SetPoint("TOPLEFT",48,-36)
end
SGM:On("SGM_READY",function() A:Create() end)
local validAlertKind={NEARBY=true,STEALTH=true,KOS=true,HIGH=true,TARGET=true,SOS=true}

local function normalizeAlertArgs(kind,name,p)
 -- Accept both the normal form (kind, name, playerData) and the compact
 -- test/legacy form (name, playerData). Never allow a Lua table address
 -- to reach the visible alert text.
 if type(name)=="table" and p==nil and not validAlertKind[kind] then
  p=name
  name=kind
  kind="NEARBY"
 end

 if type(name)=="table" then
  p=p or name
  name=name.name or name.playerName or name.fullName
 end

 p=type(p)=="table" and p or {}
 if type(name)~="string" or name=="" or name:match("^table:") then
  name=p.name or p.playerName or p.fullName or L["Unknown"]
 end
 if type(name)~="string" or name=="" or name:match("^table:") then
  name=L["Unknown"]
 end

 if not validAlertKind[kind] then kind="NEARBY" end
 return kind,name,p
end

SGM:On("SGM_ALERT",function(kind,name,p)
 if not A.frame then return end
 kind,name,p=normalizeAlertArgs(kind,name,p)
 setAlertIcon(kind,p)
 local r,g,b=SGM:ClassColor(p and p.class)
 local stealthHead=L["STEALTH PLAYER DETECTED NEARBY"]
 if kind=="STEALTH" then
  local class=(p and p.class) or L["STEALTH PLAYER"]
  if class=="ROGUE" or class=="DRUID" then
   local recentDirection=p.lastDirection and p.lastDirectionAt and (time()-p.lastDirectionAt)<=10
   stealthHead=class..(recentDirection and (" LAST SEEN "..p.lastDirection) or " DETECTED NEARBY")
  end
 end
 local nearbyHead=L["ENEMY PLAYER DETECTED NEARBY"]
 if p and p.class=="ROGUE" then nearbyHead=L["ROGUE DETECTED NEARBY"]
 elseif p and p.class=="DRUID" then nearbyHead=L["DRUID DETECTED NEARBY"] end
 A.head:SetText(kind==L["KOS"] and L["KILL ON SIGHT DETECTED"] or kind=="TARGET" and L["ENEMY TARGETING YOU"] or kind=="SOS" and L["ENEMY GROUP DETECTED"] or kind=="HIGH" and L["HIGH THREAT ENEMY"] or kind=="STEALTH" and stealthHead or nearbyHead)
 local level=p and tonumber(p.level)
 local levelText=(level and level>0) and tostring(math.floor(level)) or "??"
 A.name:SetText(name.." - "..levelText); A.name:SetTextColor(r,g,b)
 A.zone:SetText((p and p.zone) or "")
 A.frame:Show(); A.frame:SetAlpha(1)
 local start=GetTime(); A.frame:SetScript("OnUpdate",function(self) local d=GetTime()-start; if d>5 then self:Hide(); self:SetScript("OnUpdate",nil) elseif d>4 then self:SetAlpha(5-d) end end)
end)

SGM:On("SGM_ENEMY_CITY_ENABLED",function()
 if not A.frame then return end
 A.icon:SetTexCoord(0,1,0,1)
 A.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
 A.head:SetText(L["ENEMY CITY DETECTED"])
 A.name:SetText(L["Enemy City Mode Enabled"])
 A.name:SetTextColor(1,.82,0)
 A.zone:SetText("")
 A.frame:Show(); A.frame:SetAlpha(1)
 local start=GetTime(); A.frame:SetScript("OnUpdate",function(self) local d=GetTime()-start; if d>5 then self:Hide(); self:SetScript("OnUpdate",nil) elseif d>4 then self:SetAlpha(5-d) end end)
end)
