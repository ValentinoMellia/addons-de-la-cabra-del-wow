-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface == 16001 then return end
local _, Addon = ...
local Module=CreateFrame('Frame')
Addon.MidnightTargetPortrait=Module
_G.OmniCC_GODMODE_TargetPortrait=Module
local DB_NAME='OmniCC_GODMODE_MidnightTargetPortraitDB'
local defaults={enabled=true,showCC=true,showDamageDebuffs=true,showSlows=true,showUtility=true,showAllClassEffects=true}
local db,baseContainer,ccContainer,portraitLayer,testOverlay,testIcon,testCD
local portraitGeneration=0
local watchedTPerlPortrait
local STRATA_BELOW={BACKGROUND='BACKGROUND',LOW='BACKGROUND',MEDIUM='LOW',HIGH='MEDIUM',DIALOG='HIGH',FULLSCREEN='DIALOG',FULLSCREEN_DIALOG='FULLSCREEN',TOOLTIP='FULLSCREEN_DIALOG'}

-- Portrait countdowns follow the Action Bars (default) theme while Auto-Fit is OFF.
-- Auto-Fit ON temporarily selects godmode_autofit without mutating saved themes.
local function ApplyPortraitCountdownTheme(cd)
 if not cd then return end
 local p=Addon and Addon.db and Addon.db.profile
 local auto=p and p.godmodeAutoFitEnabled == true
 local t=p and p.themes and p.themes.default
 if not t then return end
 -- Apply the complete selected text theme, not only a formatter. The native
 -- countdown keeps its own duration clock; no aura container is rebuilt.
 if Addon.CreateThemer then
  local ok,styler=pcall(Addon.CreateThemer,Addon,t)
  if ok and type(styler)=='function' then pcall(styler,cd) end
 end
 if Addon.CreateCountdownFormatter and cd.SetCountdownFormatter then
  local ok,fmt=pcall(Addon.CreateCountdownFormatter,Addon,t)
  if ok and fmt then
   pcall(cd.SetCountdownFormatter,cd,fmt)
   cd._ogmActionColorFormatter=fmt
   cd._ogmActionColorSource=t
  end
 end
 -- Portrait aura cooldowns belong to Action Bars, independently of Auto-Fit.
 -- Reapply the native swipe immediately: Blizzard can retain the old swipe tint
 -- when the text themer/formatter changes without an aura lifecycle update.
 if cd.SetSwipeColor and t.themeCooldown ~= false and t.themeSwipeColor and t.swipeColor and Addon.HexToRGBA then
  local ok,r,g,b,a=pcall(Addon.HexToRGBA,t.swipeColor)
  if ok and r then pcall(cd.SetSwipeColor,cd,r,g,b,a or 1) end
 end
 -- Portrait-only placement: keep native cooldown digits centered regardless of theme anchor.
 -- Apply after the theme styler so bottom/top theme settings cannot move them.
 if cd.GetCountdownFontString then
  local ok,fs=pcall(cd.GetCountdownFontString,cd)
  if ok and fs then
   pcall(function()
    fs:ClearAllPoints()
    fs:SetPoint('CENTER',cd,'CENTER',0,0)
    fs:SetJustifyH('CENTER')
    fs:SetJustifyV('MIDDLE')
   end)
  end
 end
 if auto and cd.GetCountdownFontString then
  local ok,fs=pcall(cd.GetCountdownFontString,cd)
  if ok and fs and fs.GetFont and fs.SetFont then
   local good,font,_,flags=pcall(fs.GetFont,fs)
   local width=cd.GetWidth and cd:GetWidth() or 0
   local height=cd.GetHeight and cd:GetHeight() or 0
   local slider=math.max(0,math.min(99,tonumber(t.fontSize) or 50))
   local preferred=5+10*slider/99
   local bound=math.max(1,math.min(width or 0,height or 0)*0.82)
   if good and font and width>0 and height>0 then
    pcall(fs.SetFont,fs,font,math.min(preferred,bound),flags)
    if Addon.FitAutoText then pcall(Addon.FitAutoText,Addon,fs,cd,t) end
   end
  end
 end
end

function Module:RefreshThemeAppearance()
 for _,container in ipairs({baseContainer,ccContainer}) do
  if container and container.GetChildren then
   for _,child in ipairs({container:GetChildren()}) do
    local cd=child and (child.cooldown or child.Cooldown or (child.GetDurationCooldown and child:GetDurationCooldown()))
    if cd then ApplyPortraitCountdownTheme(cd) end
   end
  end
 end
 if testCD then ApplyPortraitCountdownTheme(testCD) end
end

local function EnsureDB() _G[DB_NAME]=_G[DB_NAME] or {}; db=_G[DB_NAME]; for k,v in pairs(defaults) do if db[k]==nil then db[k]=v end end end
-- TPerl compatibility: resolve only a visible, real portrait region. Never
-- reparent or modify TPerl's own portrait or secure unit frames.
local function TPerlPortrait(unit)
    local prefix = unit == 'player' and 'Player' or 'Target'
    -- TPerl's real portrait is frame.portraitFrame. Avoid sparse ipairs lists:
    -- a nil first entry would terminate iteration before reaching TPerl.
    for _,frameName in ipairs({'TPerl_'..prefix, 'XPerl_'..prefix}) do
        local frame = _G[frameName]
        if frame and frame.IsShown and frame:IsShown() then
            local p = frame.portraitFrame or frame.portrait or frame.Portrait
            if p and p.GetParent and p.GetWidth and p.GetHeight
                and p:GetWidth() > 8 and p:GetHeight() > 8
                and (not p.IsShown or p:IsShown()) then
                return p
            end
        end
    end
    return nil
end
local function TF()
 local tp=TPerlPortrait('target')
 return tp and (tp:GetParent() or _G.TargetFrame) or _G.TargetFrame
end
local function Portrait()
 local tp=TPerlPortrait('target'); if tp then return tp end
 local tf=TF(); if not tf then return nil end
 local c=tf.TargetFrameContainer
 if c then
  if c.Portrait then return c.Portrait end
  if c.TargetPortrait then return c.TargetPortrait end
  if c.TargetFrameContent and c.TargetFrameContent.TargetFrameContentMain then local m=c.TargetFrameContent.TargetFrameContentMain; if m.Portrait then return m.Portrait end end
 end
 return tf.portrait or _G.TargetFramePortrait
end
local function Mask() local tf=TF(); local c=tf and tf.TargetFrameContainer; return c and c.PortraitMask or nil end
local function Supported()
 local build=select(4,GetBuildInfo()); if type(build)=='number' and build<120100 then return false end
 local ok,f=pcall(CreateFrame,'AuraContainer',nil,UIParent,'CustomAuraContainerTemplate'); if not ok or not f then return false end
 local yes=type(f.AddAuraGroup)=='function'; if f.SetEnabled then pcall(f.SetEnabled,f,false) end f:Hide(); return yes
end
local function PortraitLayer()
 if portraitLayer then return portraitLayer end
 local p=Portrait(); if not p then return nil end; if TPerlPortrait('target') == p then return nil end; local parent=p:GetParent(); if not parent then return nil end
 if p:GetNumPoints()~=1 then return nil end
 local w,h=p:GetWidth(),p:GetHeight(); if type(w)~='number' or type(h)~='number' then return nil end
 local point,rel,rp,x,y=p:GetPoint(1); if not point then return nil end
 local l=CreateFrame('Frame','OmniCC_GODMODE_TargetPortraitLayer',parent); l:SetAllPoints(parent); l:SetFrameStrata(STRATA_BELOW[parent:GetFrameStrata()] or 'BACKGROUND'); l:SetFrameLevel(1)
 p:SetParent(l); p:ClearAllPoints(); p:SetPoint(point,rel or l,rp or point,x or 0,y or 0); portraitLayer=l; return l
end
local function InitButton(button,size)
 button:SetSize(size,size); button:SetFlattensRenderLayers(false)
 -- Do not draw a square black backing outside the portrait mask.
 local icon=button:CreateTexture(nil,'BACKGROUND',nil,1); icon:SetAllPoints(); icon:SetTexCoord(.1,.9,.1,.9); local m=Mask(); if m and icon.AddMaskTexture then pcall(icon.AddMaskTexture,icon,m) end; button:SetIcon(icon)
 local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate'); cd:SetAllPoints(); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false); if m and cd.SetSwipeTexture then cd:SetSwipeTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask') end; button:SetDurationCooldown(cd); ApplyPortraitCountdownTheme(cd); button:EnableMouse(false)
end
local function NewContainer(name,filter,level)
 local p=Portrait(); local tf=TF(); if not p or not tf then return nil end; local owner=PortraitLayer() or p:GetParent() or tf
 local w,h=p:GetWidth(),p:GetHeight(); if type(w)~='number' or type(h)~='number' then return nil end; local size=math.max(18,math.floor(math.min(w,h)+.5))
 local coverW,coverH=size,size; if TPerlPortrait('target') == p then coverW,coverH=math.max(18,math.floor(w+.5)),math.max(18,math.floor(h+.5)) end
 portraitGeneration=portraitGeneration+1
 local c=CreateFrame('AuraContainer',nil,owner,'CustomAuraContainerTemplate'); c:Hide(); c:SetSize(coverW,coverH); c:SetPoint('CENTER',p,'CENTER',0,0); c:SetFrameStrata(owner:GetFrameStrata()); c:SetFrameLevel((owner:GetFrameLevel() or 1)+level); if c.SetIgnoreParentScale then c:SetIgnoreParentScale(false) end
 c:SetUnit('target'); c:AddAuraGroup(name..'_group_'..portraitGeneration,filter,{maxFrameCount=1,candidateFilters={},sortMethod=AuraContainerSortMethod and AuraContainerSortMethod.AuraInstanceIDOnly or nil,sortDirection=AuraContainerSortDirection and AuraContainerSortDirection.Reverse or nil,initializeFrame=function(b) InitButton(b,size); if coverW~=size or coverH~=size then b:SetSize(coverW,coverH) end end,layout={elementWidth=coverW,elementHeight=coverH,elementSpacing=0,lineSpacing=0}}); if c.SetEnabled then c:SetEnabled(true) end; c:Show(); return c
end
local function Destroy() for _,c in ipairs({baseContainer,ccContainer}) do if c then if c.SetEnabled then pcall(c.SetEnabled,c,false) end c:Hide() end end baseContainer=nil; ccContainer=nil end
local function Build()
 EnsureDB(); Destroy(); if Module._compatSuspended then return false end; if db.enabled==false or not Supported() or not UnitExists('target') then return false end
 local tp=TPerlPortrait('target')
 if tp and watchedTPerlPortrait~=tp then
  watchedTPerlPortrait=tp
  tp:HookScript('OnSizeChanged',function()
   if not InCombatLockdown or not InCombatLockdown() then
    C_Timer.After(0,function() if db and db.enabled~=false then Build() end end)
   end
  end)
 end
 -- Base layer: every harmful aura cast by player/pet/vehicle. This is the
 -- future-proof all-class path and replaces the old spell-ID guessing.
 if db.showAllClassEffects~=false or db.showDamageDebuffs==true or db.showUtility~=false then baseContainer=NewContainer('OmniCC_GODMODE_TargetAllMine','HARMFUL|!CROWD_CONTROL',2) end
 -- Higher layer: Blizzard-curated CC (includes stun/fear/silence/root/slow).
 if db.showCC~=false or db.showSlows~=false then ccContainer=NewContainer('OmniCC_GODMODE_TargetCCMine','HARMFUL|PLAYER|CROWD_CONTROL',4) end
 return baseContainer~=nil or ccContainer~=nil
end
local function Test()
 local p=Portrait(); if not p then print('|cffff4040OmniCC GODMODE:|r target portrait not found.'); return end
 if not testOverlay then local owner=portraitLayer or p:GetParent(); testOverlay=CreateFrame('Frame','OmniCC_GODMODE_TargetPortraitTest',owner); testOverlay:SetAllPoints(p); testOverlay:SetFrameStrata(owner:GetFrameStrata()); testOverlay:SetFrameLevel((owner:GetFrameLevel() or 1)+8); testIcon=testOverlay:CreateTexture(nil,'ARTWORK'); testIcon:SetAllPoints(); testIcon:SetTexCoord(.1,.9,.1,.9); local m=Mask(); if m and testIcon.AddMaskTexture then pcall(testIcon.AddMaskTexture,testIcon,m) end; testCD=CreateFrame('Cooldown',nil,testOverlay,'CooldownFrameTemplate'); testCD:SetAllPoints(); testOverlay:Hide() end
 testIcon:SetTexture(136116); testCD:SetCooldown(GetTime(),10); testOverlay:Show(); C_Timer.After(10,function() if testOverlay then testOverlay:Hide() end end)
end
-- Appearance-only live refresh: native AuraContainer cooldowns can be nested
-- beneath secure aura buttons, not necessarily immediate container children.
local function RefreshPortraitCooldownTree(frame, depth, seen)
 if not frame or depth > 7 or seen[frame] then return end
 seen[frame]=true
 local cd=frame.cooldown or frame.Cooldown
 if frame.GetDurationCooldown then
  local ok, native=pcall(frame.GetDurationCooldown,frame)
  if ok and native then cd=native end
 end
 if cd then ApplyPortraitCountdownTheme(cd) end
 if frame.GetObjectType then
  local ok, kind=pcall(frame.GetObjectType,frame)
  if ok and kind=='Cooldown' then ApplyPortraitCountdownTheme(frame) end
 end
 if frame.GetChildren then
  for _,child in ipairs({frame:GetChildren()}) do
   RefreshPortraitCooldownTree(child,depth+1,seen)
  end
 end
end
function Module:RefreshThemeAppearance()
 local seen={}
 for _,container in ipairs({baseContainer,ccContainer}) do
  RefreshPortraitCooldownTree(container,0,seen)
 end
 if testCD then ApplyPortraitCountdownTheme(testCD) end
end


function Module:GetOption(k) EnsureDB(); return db[k] end
function Module:SetOption(k,v) EnsureDB(); db[k]=v and true or false; if not InCombatLockdown or not InCombatLockdown() then C_Timer.After(0,Build) end end
function Module:Refresh() if not InCombatLockdown or not InCombatLockdown() then Build() end end
function Module:Test() Test() end
function Module:Debug() print(('OmniCC GODMODE Target Portrait: secureAuraContainer=%s target=%s base=%s cc=%s combat=%s'):format(tostring(Supported()),UnitExists('target') and 'YES' or 'NO',baseContainer and 'YES' or 'NO',ccContainer and 'YES' or 'NO',tostring(InCombatLockdown and InCombatLockdown() or false))) end
Module:RegisterEvent('PLAYER_LOGIN'); Module:RegisterEvent('PLAYER_ENTERING_WORLD'); Module:RegisterEvent('PLAYER_TARGET_CHANGED'); Module:RegisterEvent('PLAYER_REGEN_ENABLED')
Module:SetScript('OnEvent',function(_,event) if event=='PLAYER_TARGET_CHANGED' then Destroy(); C_Timer.After(0,Build) elseif event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then C_Timer.After(.6,Build) elseif event=='PLAYER_REGEN_ENABLED' then C_Timer.After(0,Build) end end)
SLASH_OGMTPTEST1='/ogmtptest'; SlashCmdList.OGMTPTEST=function() Test() end
SLASH_OGMTPDEBUG1='/ogmtpdebug'; SlashCmdList.OGMTPDEBUG=function() Module:Debug() end
EnsureDB()

-- Complete a queued appearance rebind after combat; never rebuild secure
-- AuraContainers while combat lockdown is active.
Module:HookScript('OnEvent', function(self, event)
 if event == 'PLAYER_REGEN_ENABLED' and self._ogmPortraitThemeRebindPending then
  self._ogmPortraitThemeRebindPending=nil
  if self.Refresh then self:Refresh() end
 end
end)
