-- Optional player HoT lane. Separate from Player CC and nameplate aura lifecycle.
local interface = select(4, GetBuildInfo())
if interface ~= 16001 and interface < 120000 then return end
local _, Addon = ...
local CC = (interface == 16001) and Addon.ForeverPlayerCC or Addon.MidnightPlayerCC
local savedName = interface == 16001 and 'OmniCC_GODMODE_ForeverPlayerCCDB' or 'OmniCC_GODMODE_MidnightPlayerCCDB'
local HOT = CreateFrame('Frame')
Addon.PlayerHoTTracker = HOT
local known = {
 [139]=true,[774]=true,[8936]=true,[33763]=true,[48438]=true,[155777]=true,
 [61295]=true,[974]=true,[51945]=true,[114942]=true,[124682]=true,
 [115175]=true,[119611]=true,[116670]=true,[196725]=true,[157982]=true,
 [200389]=true,[53563]=true,[156322]=true,[102351]=true,[18562]=true,
 [207386]=true,[198590]=true,[29203]=true,[26980]=true,[27813]=true,
}
local frames, shown = {}, {}
-- Last successfully decoded HoTs. Combat aura APIs can temporarily return
-- unreadable/secret values; never interpret that as an aura removal.
local lastReadable = {}
local lastCombatScan = 0
local auraInstanceCache = {}
local combatHold = {} -- preserve known active HoTs across combat aura-reader gaps
local scanReadable = false
-- Self-cast fallback for clients that mark player aura fields secret in combat.
-- This is deliberately limited to successful spells cast on the player.
local castHoTs = {}
local castDurations = {
 [774]=12,[139]=15,[8936]=21,[33763]=15,[48438]=7,
 [61295]=18,[974]=600,[51945]=15,[114942]=15,[124682]=6,
 [119611]=18,[53563]=60,[102351]=30,
}
local function RecordSelfCast(spellID)
 if type(spellID)~='number' or not castDurations[spellID] then return end
 local duration=castDurations[spellID]
 local icon
 if C_Spell and C_Spell.GetSpellTexture then
  local ok,v=pcall(C_Spell.GetSpellTexture,spellID); if ok then icon=v end
 elseif GetSpellTexture then
  local ok,v=pcall(GetSpellTexture,spellID); if ok then icon=v end
 end
 if type(icon)~='number' and type(icon)~='string' then return end
 castHoTs[spellID]={id=spellID,icon=icon,duration=duration,expiration=GetTime()+duration}
end

-- Classic/Forever uses rank-specific spell IDs. A rank can differ from
-- the base ID, so recognize both rank IDs and localized spell names.
local rankIds = {
  [1058]=true,[1430]=true,[2090]=true,[2091]=true,[3627]=true,[8910]=true,[9839]=true,[9840]=true,[25299]=true,[26982]=true,[48440]=true,[48441]=true, -- Rejuvenation
  [8938]=true,[8939]=true,[8940]=true,[8941]=true,[9750]=true,[9856]=true,[9857]=true,[9858]=true,[26980]=true,[48442]=true,[48443]=true, -- Regrowth
  [6074]=true,[6075]=true,[6076]=true,[6077]=true,[6078]=true,[10927]=true,[10928]=true,[10929]=true,[25315]=true,[25221]=true,[48067]=true,[48068]=true, -- Renew
}
local knownNames = {}
local namesBuilt = false
local function SpellName(id)
 if GetSpellInfo then
  local ok,name=pcall(GetSpellInfo,id)
  if ok and type(name)=='string' then return name end
 end
 if C_Spell and C_Spell.GetSpellName then
  local ok,name=pcall(C_Spell.GetSpellName,id)
  if ok and type(name)=='string' then return name end
 end
end
local function IsKnown(id, name)
 if type(id)=='number' and (known[id] or rankIds[id]) then return true end
 if type(name)~='string' then return false end
 if not namesBuilt then
  namesBuilt=true
  for spell in pairs(known) do local n=SpellName(spell); if n then knownNames[n]=true end end
  for spell in pairs(rankIds) do local n=SpellName(spell); if n then knownNames[n]=true end end
 end
 return knownNames[name] == true
end
local dragAnchor
local DB
local function Position()
 local db=DB()
 if type(db.hotsAnchorX)=='number' and type(db.hotsAnchorY)=='number' then return db.hotsAnchorX,db.hotsAnchorY end
 local x,y=0,135
 if CC and CC.GetPosition then x,y=CC:GetPosition() end
 return x+db.hotsOffsetX,y+db.hotsOffsetY
end
-- Combat-safe HoT lane: copy the working friendly-nameplate native
-- AuraContainer group configuration, NOT its combat aura payload reader.
-- Native ownership is initialized out of combat and left alone in combat.
local native, nativeBound, nativeFailed
local nativeLayoutSize
local nativeButtons = {}
local function ResizeNativeButtons(size)
    for button in pairs(nativeButtons) do
        if button and button.SetSize then button:SetSize(size,size) end
    end
end
local nativeCandidates={includeSpellIDs={}}
for id in pairs(known) do nativeCandidates.includeSpellIDs[id]=true end
for id in pairs(rankIds) do nativeCandidates.includeSpellIDs[id]=true end
local function InitNativeButton(button)
    local size=DB().hotsSize
    button:SetSize(size,size)
    nativeButtons[button]=true
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled,button,false) end
    if button.SetHideTooltipInCombat then pcall(button.SetHideTooltipInCombat,button,true) end
    local icon=button:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('TOPLEFT',button,'TOPLEFT',2,-2)
    icon:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-2,2)
    icon:SetTexCoord(.055,.945,.055,.945)
    button.Icon=icon
    if button.SetIcon then pcall(button.SetIcon,button,icon) end
    local edges={}
    for i=1,4 do
        local e=button:CreateTexture(nil,'OVERLAY',nil,7)
        e:SetColorTexture(.08,.96,.2,1)
        edges[i]=e
    end
    edges[1]:SetPoint('TOPLEFT');edges[1]:SetPoint('TOPRIGHT');edges[1]:SetHeight(2)
    edges[2]:SetPoint('BOTTOMLEFT');edges[2]:SetPoint('BOTTOMRIGHT');edges[2]:SetHeight(2)
    edges[3]:SetPoint('TOPLEFT',0,-2);edges[3]:SetPoint('BOTTOMLEFT',0,2);edges[3]:SetWidth(2)
    edges[4]:SetPoint('TOPRIGHT',0,-2);edges[4]:SetPoint('BOTTOMRIGHT',0,2);edges[4]:SetWidth(2)
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button)
    -- This native Cooldown must own its countdown text.  The old flags
    -- noCooldownCount/noOCC suppressed GODMODE's and Blizzard's timers.
    cd.OGMPlayerHoTNative=true
    if cd.SetDrawSwipe then pcall(cd.SetDrawSwipe,cd,false) end
    if cd.SetDrawEdge then pcall(cd.SetDrawEdge,cd,false) end
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,false) end
    if cd.SetMinimumCountdownDuration then pcall(cd.SetMinimumCountdownDuration,cd,0) end
    if cd.SetCountdownAbbrevThreshold then pcall(cd.SetCountdownAbbrevThreshold,cd,60) end
    button.Cooldown=cd
    if button.SetDurationCooldown then pcall(button.SetDurationCooldown,button,cd) end
    -- Mirror the working nameplate native timer path: Blizzard owns the
    -- protected remaining-time value; GODMODE only styles its font/formatter.
    local function styleNativeTimer()
        if not cd or not cd.GetCountdownFontString then return end
        local ok,fs=pcall(cd.GetCountdownFontString,cd)
        if not ok or not fs then return end
        local profile=Addon.db and Addon.db.profile
        local theme=profile and profile.themes and profile.themes.nameplates
        local font=(theme and theme.font) or 'Fonts\\FRIZQT__.TTF'
        local size=math.max(9,math.min(48,tonumber(theme and theme.fontSize) or 14))
        local flags=(theme and theme.fontFlags) or 'OUTLINE'
        pcall(fs.SetFont,fs,font,size,flags)
        pcall(fs.SetPoint,fs,'CENTER',cd,'CENTER',0,0)
        pcall(fs.SetDrawLayer,fs,'OVERLAY',7)
        pcall(fs.Show,fs)
        if theme and Addon.CreateCountdownFormatter and cd.SetCountdownFormatter then
            local okFmt,formatter=pcall(Addon.CreateCountdownFormatter,Addon,theme)
            if okFmt and formatter then pcall(cd.SetCountdownFormatter,cd,formatter) end
        end
    end
    styleNativeTimer()
    if C_Timer and C_Timer.After then C_Timer.After(0,styleNativeTimer) end
end
local function ConfigureNative()
    if native then return true end
    if nativeFailed or (InCombatLockdown and InCombatLockdown()) then return false end
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo('CustomAuraContainerTemplate')) then return false end
    local ok,c=pcall(CreateFrame,'AuraContainer','OmniCC_GODMODE_PlayerHoTNativeV2',UIParent,'CustomAuraContainerTemplate')
    if not ok or not c or not c.AddAuraGroup or not c.SetUnit then nativeFailed=true;return false end
    local initialSize=DB().hotsSize
    c:SetSize(12*(initialSize+5),initialSize+5);c:Hide()
    local initialSize=DB().hotsSize
    local layout={elementWidth=initialSize,elementHeight=initialSize,elementSpacing=5,lineSpacing=0}
    local group='ogm_player_hots'
    local added=pcall(c.AddAuraGroup,c,group,'HELPFUL',{maxFrameCount=12,candidateFilters=nativeCandidates,initializeFrame=InitNativeButton,layout=layout})
    if not added then nativeFailed=true;pcall(c.Hide,c);return false end
    if c.SetAuraGroupFilterString then pcall(c.SetAuraGroupFilterString,c,group,'HELPFUL') end
    if c.SetAuraGroupCandidateFilters then pcall(c.SetAuraGroupCandidateFilters,c,group,nativeCandidates) end
    if c.SetAuraGroupMaxFrameCount then pcall(c.SetAuraGroupMaxFrameCount,c,group,12) end
    if c.SetAuraGroupLayout then pcall(c.SetAuraGroupLayout,c,group,layout) end
    if c.SetFlowLayoutMaximumLineSize then pcall(c.SetFlowLayoutMaximumLineSize,c,12*(initialSize+5)) end
    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPRIGHT') end
    local FD=AnchorUtil and AnchorUtil.FlowDirection
    if c.SetFlowLayoutGrowthDirection and FD and FD.Left and FD.Down then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Left,FD.Down) end
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    native=c
    return true
end
local function RefreshNative()
    if not ConfigureNative() then return false end
    -- Blizzard's secure container handles combat UNIT_AURA internally.
    -- Never call SetUnit, Show, Hide, or reanchor it during combat.
    if InCombatLockdown and InCombatLockdown() then return nativeBound end
    local db=DB()
    if not db.hotsEnabled then
        if nativeBound then
            if native.SetEnabled then pcall(native.SetEnabled,native,false) end
            pcall(native.SetUnit,native,nil);native:Hide();nativeBound=false
        end
        return false
    end
    local x,y=Position()
    native:ClearAllPoints()
    native:SetPoint('TOPRIGHT',UIParent,'CENTER',x+db.hotsSize/2,y+db.hotsSize/2)
    native:SetSize(12*(db.hotsSize+5),db.hotsSize+5)
    local layout={elementWidth=db.hotsSize,elementHeight=db.hotsSize,elementSpacing=5,lineSpacing=0}
    if nativeLayoutSize ~= db.hotsSize then
        nativeLayoutSize = db.hotsSize
        if native.SetAuraGroupLayout then pcall(native.SetAuraGroupLayout,native,'ogm_player_hots',layout) end
        if native.SetFlowLayoutMaximumLineSize then pcall(native.SetFlowLayoutMaximumLineSize,native,12*(db.hotsSize+5)) end
        ResizeNativeButtons(db.hotsSize)
        if native.UpdateFlowLayout then pcall(native.UpdateFlowLayout,native) end
        if native.Layout then pcall(native.Layout,native) end
        if C_Timer and C_Timer.After then
            local expected=db.hotsSize
            C_Timer.After(0,function()
                if not (InCombatLockdown and InCombatLockdown()) and nativeLayoutSize==expected then
                    ResizeNativeButtons(expected)
                    if native.UpdateFlowLayout then pcall(native.UpdateFlowLayout,native) end
                end
            end)
        end
    end
    if not nativeBound then
        -- Exactly the working nameplate lifecycle: disable, clear unit, bind,
        -- then enable/show. Never force UpdateAllAuras synchronously.
        if native.SetEnabled then pcall(native.SetEnabled,native,false) end
        pcall(native.SetUnit,native,nil)
        local ok=pcall(native.SetUnit,native,'player')
        if not ok then return false end
        if native.SetEnabled then pcall(native.SetEnabled,native,true) end
        nativeBound=true
    end
    native:Show()
    return true
end
local pending = false
DB = function()
 local db = _G[savedName]
 if type(db) ~= 'table' then db = {}; _G[savedName] = db end
 if db.hotsEnabled == nil then db.hotsEnabled = false end -- opt-in; never change existing CC settings
 -- One-time migration: earlier builds saved tiny 18-32px values, so the
 -- new 64px default was never applied to existing installations.
 if db.hotsSize == nil then
  db.hotsSize = 64
 elseif not db.hotsLargeDefaultMigrated then
  if type(db.hotsSize) ~= 'number' or db.hotsSize < 40 then db.hotsSize = 64 end
 end
 db.hotsLargeDefaultMigrated = true
 if db.hotsOffsetX == nil then db.hotsOffsetX = -125 end
 if db.hotsOffsetY == nil then db.hotsOffsetY = 0 end
 return db
end
-- HoT visuals read the existing Nameplates theme; they never touch nameplate frames.
local function NameplateTheme()
 local profile=Addon.db and Addon.db.profile
 return profile and profile.themes and profile.themes.nameplates
end
local function ColorRGB(hex)
 if type(hex)~='string' then return 1,1,1 end
 hex=hex:gsub('^#','')
 if #hex<6 then return 1,1,1 end
 local r,g,b=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
 if not r or not g or not b then return 1,1,1 end
 return r/255,g/255,b/255
end
local function ApplyTextStyle(f,remain)
 local theme=NameplateTheme()
 local size=DB().hotsSize
 local font=(theme and theme.font) or 'Fonts\\FRIZQT__.TTF'
 local fontSize=math.max(9,math.min(48,tonumber(theme and theme.fontSize) or math.floor(size*.42)))
 local flags=(theme and theme.fontFlags) or 'OUTLINE'
 local signature=tostring(font)..':'..tostring(fontSize)..':'..tostring(flags)
 if f._hotFontSignature~=signature then
  if not pcall(f.timer.SetFont,f.timer,font,fontSize,flags) then f.timer:SetFont('Fonts\\FRIZQT__.TTF',fontSize,'OUTLINE') end
  f._hotFontSignature=signature
 end
 local color=theme and theme.defaultTextColor
 if theme and type(theme.textColors)=='table' then
  local best
  for _,entry in pairs(theme.textColors) do
   if type(entry)=='table' then
    local threshold=tonumber(entry.threshold)
    if threshold and remain<=threshold and (not best or threshold<best) then
     best=threshold; color=entry.color
    end
   end
  end
 end
 local r,g,b=ColorRGB(color)
 if r~=f._hotR or g~=f._hotG or b~=f._hotB then
  f.timer:SetTextColor(r,g,b,1)
  f._hotR,f._hotG,f._hotB=r,g,b
 end
end
local function MakeGreenBorder(f)
 -- Four lightweight textures: no extra cooldowns, hooks, or nameplate refreshes.
 local border={}
 for i=1,4 do
  local t=f:CreateTexture(nil,'OVERLAY')
  t:SetColorTexture(.15,1,.18,1)
  border[i]=t
 end
 border[1]:SetPoint('TOPLEFT',f,'TOPLEFT',0,0); border[1]:SetPoint('TOPRIGHT',f,'TOPRIGHT',0,0); border[1]:SetHeight(2)
 border[2]:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',0,0); border[2]:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',0,0); border[2]:SetHeight(2)
 border[3]:SetPoint('TOPLEFT',f,'TOPLEFT',0,0); border[3]:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',0,0); border[3]:SetWidth(2)
 border[4]:SetPoint('TOPRIGHT',f,'TOPRIGHT',0,0); border[4]:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',0,0); border[4]:SetWidth(2)
end
local function NewIcon(i)
 if frames[i] then return frames[i] end
 local f = CreateFrame('Frame',nil,UIParent)
 f.tex=f:CreateTexture(nil,'ARTWORK'); f.tex:SetAllPoints(); f.tex:SetTexCoord(.08,.92,.08,.92)
 f.cd=CreateFrame('Cooldown',nil,f,'CooldownFrameTemplate'); f.cd:SetAllPoints()
 f.cd.noCooldownCount=true; f.cd.noOCC=true
 if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
 if f.cd.SetDrawSwipe then f.cd:SetDrawSwipe(false) end
 if f.cd.SetDrawEdge then f.cd:SetDrawEdge(false) end
 f.timer=f:CreateFontString(nil,'OVERLAY'); f.timer:SetPoint('CENTER'); f.timer:SetFont('Fonts\\FRIZQT__.TTF',14,'OUTLINE')
 MakeGreenBorder(f)
 f:Hide(); frames[i]=f; return f
end
local function Clear()
 for _,f in ipairs(frames) do f:Hide(); f.expiry=nil; f.timer:SetText('') end
 wipe(shown); wipe(lastReadable); wipe(combatHold); wipe(auraInstanceCache); wipe(castHoTs); HOT:SetScript('OnUpdate',nil)
end
local function AddReadable(id, icon, expiration, duration, name)
 if #shown >= 12 or not IsKnown(id,name) then return end
 if (type(icon)~='number' and type(icon)~='string') or type(expiration)~='number' or type(duration)~='number' or duration<=0 then return end
 if expiration <= GetTime() then return end
 shown[#shown+1]={id=id,icon=icon,expiration=expiration,duration=duration}
 scanReadable=true
end
local function AddAura(a)
 if not a then return end
 -- Secret-valued aura fields are not readable on protected Midnight builds.
 -- Keep the display safe; never taint protected Blizzard aura frames.
 local ok,id,icon,expiration,duration,name=pcall(function()
  return a.spellId or a.spellID, a.icon or a.iconFileID, a.expirationTime, a.duration, a.name
 end)
 if ok then
  local safe=pcall(AddReadable,id,icon,expiration,duration,name)
  if not safe then return end
 end
end
local function ScanLegacy()
 -- Forever has shipped both classic UnitBuff and modern aura APIs.
 -- Read helpful buffs only, and do not stop on an API error if another
 -- supported reader can still return the player's auras.
 local getter=UnitBuff or UnitAura
 if not getter then return false end
 local found=false
 for i=1,40 do
  -- Classic UnitBuff returns (name, icon, count, dispelType, duration, expiration, source, ... spellId).
  -- Prefer this reader on Forever; modern aura objects are not always usable.
  local ok,name,icon,count,debuffType,duration,expiration,source,stealable,consolidate,id=pcall(getter,'player',i,'HELPFUL')
  if not ok then break end
  if not name then break end
  local before=#shown
  pcall(AddReadable,id,icon,expiration,duration,name)
  if #shown>before then found=true end
 end
 return found
end
local function ScanModern()
 if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
 local found=false
 for i=1,80 do
  local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,'player',i,'HELPFUL')
  if not ok then return found end
  if not a then break end
  local before=#shown
  AddAura(a)
  if #shown>before then found=true end
 end
 return found
end
-- UNIT_AURA's added/updated aura instance IDs are the preferred source when
-- full aura enumeration becomes restricted in combat. These are read only;
-- never modify Blizzard aura frames or touch nameplate ownership.
local function RecordAuraInstance(a)
 if not a then return end
 local ok,instance=pcall(function() return a.auraInstanceID end)
 if not ok or type(instance)~='number' then return end
 local before=#shown
 local okData,id,icon,expiration,duration,name=pcall(function()
  return a.spellId or a.spellID,a.icon or a.iconFileID,a.expirationTime,a.duration,a.name
 end)
 if not okData then return end
 if not pcall(AddReadable,id,icon,expiration,duration,name) then return end
 if #shown>before then
  local record=shown[#shown]
  auraInstanceCache[instance]={id=record.id,icon=record.icon,expiration=record.expiration,duration=record.duration}
 end
end
local function ProcessAuraUpdate(updateInfo)
 if type(updateInfo)~='table' then return end
 if updateInfo.isFullUpdate then wipe(auraInstanceCache) end
 if type(updateInfo.removedAuraInstanceIDs)=='table' then
  for _,instance in ipairs(updateInfo.removedAuraInstanceIDs) do
   if type(instance)=='number' then auraInstanceCache[instance]=nil end
  end
 end
 if type(updateInfo.addedAuras)=='table' then
  for _,a in ipairs(updateInfo.addedAuras) do RecordAuraInstance(a) end
 end
 if type(updateInfo.updatedAuraInstanceIDs)=='table' and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
  for _,instance in ipairs(updateInfo.updatedAuraInstanceIDs) do
   if type(instance)=='number' then
    local ok,a=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,'player',instance)
    if ok and a then RecordAuraInstance(a) end
   end
  end
 end
end
local function UpdateTimers(self,elapsed)
 self.elapsed=(self.elapsed or 0)+elapsed
 if self.elapsed<.1 then return end
 self.elapsed=0
 -- Auras can be applied/removed during combat without a readable UNIT_AURA
 -- payload on some Forever builds. Reconcile at a bounded cadence, never per frame.
 if InCombatLockdown and InCombatLockdown() and HOT:IsEnabled() then
  local nowScan=GetTime()
  if nowScan-lastCombatScan>=0.75 then
   lastCombatScan=nowScan
   HOT:Refresh()
  end
 end
 local now=GetTime()
 for _,f in ipairs(frames) do
  if f:IsShown() and f.expiry then
   local remain=f.expiry-now
   local s=remain<=0 and '' or (remain<10 and string.format('%.1f',remain) or remain<60 and tostring(math.ceil(remain)) or tostring(math.ceil(remain/60))..'m')
   if f.timer:GetText()~=s then f.timer:SetText(s) end
   ApplyTextStyle(f,math.max(0,remain))
  end
 end
end
function HOT:Refresh()
 -- Use Blizzard's same combat-safe renderer as GODMODE friendly nameplates.
 -- If the native group cannot initialize, retain the original working scanner.
 if RefreshNative() then
  for _,f in ipairs(frames) do f:Hide() end
  return
 end
 local db=DB()
 if not db.hotsEnabled or not UnitExists('player') then Clear(); return end
 wipe(shown)
 scanReadable=false
 -- Modern aura data is preferred where supported; classic ranks are
 -- handled by the legacy reader when the modern API is unavailable.
 if interface == 16001 then
  -- Forever's legacy reader exposes readable player buff durations and rank IDs.
  -- Modern aura data may exist but contain different/opaque fields.
  if not ScanLegacy() then ScanModern() end
 else
  -- Modern clients: never invoke legacy APIs on a protected aura value.
  ScanModern()
 end
 local now=GetTime()
 local inCombat=InCombatLockdown and InCombatLockdown()
 -- Merge event-decoded instances with full-scan results. A protected full scan
 -- cannot be interpreted as proof that event-reported HoTs are absent.
 local seen={}
 for _,a in ipairs(shown) do if a.id then seen[tostring(a.id)..':'..tostring(a.expiration)]=true end end
 for _,a in pairs(auraInstanceCache) do
  local key=tostring(a.id)..':'..tostring(a.expiration)
  if a.expiration>now and not seen[key] and #shown<12 then
   shown[#shown+1]=a; seen[key]=true
  end
 end
 -- A successful self-cast can be known even when the aura payload is secret.
 -- Do not overwrite real readable aura data; expire inferred records promptly.
 if inCombat then
  for id,a in pairs(castHoTs) do
   if a.expiration<=now then castHoTs[id]=nil
   elseif #shown<12 then
    local present=false
    for _,existing in ipairs(shown) do if existing.id==id then present=true; break end end
    if not present then shown[#shown+1]=a end
   end
  end
 else
  wipe(castHoTs)
 end
 -- In combat, the client may return a partial or empty player aura list.
 -- Keep each previously confirmed aura individually until its expiry; a scan
 -- containing one HoT must not delete other still-active HoTs.
 if inCombat then
  for _,a in pairs(combatHold) do
   local key=tostring(a.id)..':'..tostring(a.expiration)
   if a.expiration>now and not seen[key] and #shown<12 then
    shown[#shown+1]=a; seen[key]=true
   end
  end
  for _,a in ipairs(shown) do
   if a.expiration>now then
    combatHold[tostring(a.id)..':'..tostring(a.expiration)]=a
   end
  end
  for key,a in pairs(combatHold) do
   if a.expiration<=now then combatHold[key]=nil end
  end
 else
  wipe(combatHold)
 end
 if #shown>0 then
  -- Save only decoded, finite HoTs; no writes to user profiles.
  wipe(lastReadable)
  for _,a in ipairs(shown) do
   if a.expiration>now then
    lastReadable[#lastReadable+1]={id=a.id,icon=a.icon,expiration=a.expiration,duration=a.duration}
   end
  end
 elseif inCombat then
  -- A secret/unreadable combat scan is not proof that a HoT was removed.
  -- Keep previously verified icons until their actual expiration.
  for _,a in ipairs(lastReadable) do
   if a.expiration>now then shown[#shown+1]=a end
  end
 else
  wipe(lastReadable)
 end
 local size=db.hotsSize
 local ccx,ccy=Position()
 for i=1,math.max(#shown,#frames) do
  local f=NewIcon(i); local a=shown[i]
  if a then
   f:SetSize(size,size)
   f:ClearAllPoints()
   f:SetPoint('CENTER',UIParent,'CENTER',ccx-(i-1)*(size+5),ccy)
   f.tex:SetTexture(a.icon)
   local start=a.expiration-a.duration
   if f._hotStart~=start or f._hotDuration~=a.duration then
    f.cd:SetCooldown(start,a.duration)
    f._hotStart,f._hotDuration=start,a.duration
   end
   f.expiry=a.expiration
   ApplyTextStyle(f,math.max(0,a.expiration-GetTime()))
   f:Show()
  else f:Hide(); f.expiry=nil end
 end
 self:SetScript('OnUpdate',UpdateTimers)
end
function HOT:IsEnabled() return DB().hotsEnabled==true end
function HOT:SetEnabled(v) DB().hotsEnabled=v and true or false; self:Refresh() end
function HOT:Resize(delta) local db=DB(); db.hotsSize=math.max(18,math.min(128,db.hotsSize+delta)); self:Refresh() end
function HOT:Move(dx,dy) local db=DB(); local x,y=Position(); db.hotsAnchorX=x+dx; db.hotsAnchorY=y+dy; if dragAnchor and dragAnchor:IsShown() then dragAnchor:ClearAllPoints(); dragAnchor:SetPoint('CENTER',UIParent,'CENTER',db.hotsAnchorX,db.hotsAnchorY) end; self:Refresh() end
function HOT:ResetPosition() local db=DB(); db.hotsAnchorX=nil; db.hotsAnchorY=nil; db.hotsOffsetX=-125; db.hotsOffsetY=0; if dragAnchor and dragAnchor:IsShown() then local x,y=Position(); dragAnchor:ClearAllPoints(); dragAnchor:SetPoint('CENTER',UIParent,'CENTER',x,y) end; self:Refresh() end
function HOT:ToggleAnchor()
 if not dragAnchor then
  dragAnchor=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
  dragAnchor:SetSize(265,68); dragAnchor:SetFrameStrata('DIALOG'); dragAnchor:SetMovable(true); dragAnchor:EnableMouse(true); dragAnchor:RegisterForDrag('LeftButton'); dragAnchor:SetClampedToScreen(true)
  dragAnchor:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12})
  dragAnchor:SetBackdropColor(0,.22,.12,.85)
  local label=dragAnchor:CreateFontString(nil,'OVERLAY','GameFontNormal'); label:SetPoint('CENTER',0,9); label:SetText('GODMODE HoTs')
  local hint=dragAnchor:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); hint:SetPoint('TOP',label,'BOTTOM',0,-6); hint:SetWidth(245); hint:SetJustifyH('CENTER'); hint:SetText('Drag to position / click Move to lock')
  dragAnchor:SetScript('OnDragStart',function(self) self:StartMoving() end)
  dragAnchor:SetScript('OnDragStop',function(self)
   self:StopMovingOrSizing()
   local x,y=self:GetCenter(); local ux,uy=UIParent:GetCenter()
   if x and y and ux and uy then local db=DB(); db.hotsAnchorX=x-ux; db.hotsAnchorY=y-uy; HOT:Refresh() end
  end)
  dragAnchor:Hide()
 end
 if dragAnchor:IsShown() then dragAnchor:Hide() else local x,y=Position(); dragAnchor:ClearAllPoints(); dragAnchor:SetPoint('CENTER',UIParent,'CENTER',x,y); dragAnchor:Show() end
end
HOT:RegisterEvent('PLAYER_LOGIN')
HOT:RegisterEvent('PLAYER_REGEN_DISABLED')
HOT:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED','player')
HOT:RegisterEvent('PLAYER_REGEN_ENABLED')
HOT:RegisterUnitEvent('UNIT_AURA','player')
HOT:SetScript('OnEvent',function(self,event,unit,updateInfo)
 -- This event payload was previously ignored entirely, so newly applied
 -- HoTs were never placed in the instance cache during combat.
 if nativeBound then return end
 if event=='UNIT_AURA' and unit=='player' then
  -- Protect against secret aura update fields on Forever and Midnight.
  pcall(ProcessAuraUpdate,updateInfo)
 end
 if event=='UNIT_SPELLCAST_SUCCEEDED' and HOT:IsEnabled() then
  -- UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
  -- Do not guess target from spell ID: only accept an explicit self target.
  local spellID=updateInfo
  if type(spellID)=='number' and UnitIsUnit and UnitIsUnit('target','player') then
   RecordSelfCast(spellID)
  end
 end
 if event=='PLAYER_LOGIN' then
  DB()
  -- Allocate all icon/cooldown widgets before combat, avoiding protected
  -- template construction while the player is fighting.
  for i=1,12 do NewIcon(i) end
 end
 if pending then return end
 pending=true
 C_Timer.After(.05,function() pending=false; HOT:Refresh() end)
end)
