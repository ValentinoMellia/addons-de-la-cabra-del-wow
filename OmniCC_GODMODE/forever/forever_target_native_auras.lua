-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
if _G.OmniCC_GODMODE_CooldownsOnly == true then return end
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

-- GODMODE TARGET frame auras. This intentionally mirrors the proven SELF renderer/lifecycle.
-- All AuraContainer geometry is established BEFORE SetUnit('target'); after that we do not
-- re-anchor generated/secure descendants. Only the harmless root anchor moves with TargetFrame.
local root, helpful, harmful, built
local serial, applyToken = 0, 0
local MAX_BUFFS, MAX_DEBUFFS, GAP, ROW, ROW_GAP = 18, 18, 0, 6, 0

-- The GODMODE TARGET row intentionally sits on top of Blizzard's normal
-- TargetFrame aura row.  Keep Blizzard's own duration/countdown text masked so
-- only the GODMODE timer is visible; do not hide/re-anchor the Blizzard aura
-- buttons themselves (that path is protected on Forever and caused taint).
local function suppressBlizzardTargetAuraText()
    -- Proven Forever TargetFrame suppression from the old working build:
    -- do NOT touch generated TargetFrameBuff/TargetFrameDebuff children.
    -- Blizzard's own TargetFrame_UpdateAuras reads these limits and renders
    -- zero native aura buttons, while our independent GODMODE TARGET
    -- AuraContainers below remain fully visible and keep their own timers.
    local tf=_G.TargetFrame
    if not tf then return end
    tf.maxBuffs=0
    tf.maxDebuffs=0
end

local function auraText() return Addon and Addon.ForeverAuraText end
local function sizes(kind)
    local a=auraText(); kind=kind or 'BUFF'
    local icon=(a and a.GetScopedIconSize and a:GetScopedIconSize('TARGET',kind)) or 18
    local text=(a and a.GetScopedTextSize and a:GetScopedTextSize('TARGET',kind)) or 8
    return tonumber(icon) or 18, tonumber(text) or 8
end
-- TARGET debuffs must use the same GODMODE CC semantic colors as nameplates.
-- This is intentionally target-only and event-driven: no nameplate scan/ticker.
local TargetSpellData = Addon.ForeverSpellData or _G.OmniCC_GODMODE_ForeverSpellData
local TARGET_CC_FALLBACK = {}
local function addTargetCC(cat, ids) for _,id in ipairs(ids) do TARGET_CC_FALLBACK[id]=cat end end
addTargetCC('STUN',{853,408,1833,5211,22570,20549,30283,46968,107570,119381})
addTargetCC('FEAR',{5782,5484,8122,5246,1513,2094,6358})
addTargetCC('ROOT',{339,1062,5195,5196,9852,9853,122,865,6131,10230,33395,64695,102359,116706})
addTargetCC('SLOW',{8056,8058,10472,10473,25464,1715,7372,7373,25212,12323,12324,12325})
addTargetCC('SILENCE',{15487,1330,47476,204490,31935,19647,78675})
addTargetCC('INCAP',{118,28271,28272,61721,61780,6770,2070,20066,3355,710,115078,217832})
addTargetCC('DISARM',{676,51722,233759})
local function safeAuraSpellID(button)
    local function readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
    local ok,a=pcall(function() return button.auraData or button.data or button.AuraData end)
    if ok and type(a)=='table' then
        local ok1,v=pcall(function() return a.spellId or a.spellID end)
        if ok1 and readable(v) then return tonumber(v) end
    end
    local ok2,v=pcall(function() return button.spellId or button.spellID or button.auraSpellID end)
    if ok2 and readable(v) then return tonumber(v) end
end
local function targetCCCategory(button)
    local id=safeAuraSpellID(button)
    if TargetSpellData and TargetSpellData.Category then
        local ok,cat=pcall(TargetSpellData.Category,id,nil)
        if ok and (cat=='STUN' or cat=='FEAR' or cat=='ROOT' or cat=='SLOW' or cat=='SILENCE' or cat=='INCAP' or cat=='DISARM') then return cat end
    end
    return id and TARGET_CC_FALLBACK[id] or nil
end
local function ensureTargetCCEdges(button)
    if button._ogmTargetCCEdges then return button._ogmTargetCCEdges end
    local e={}
    for i=1,4 do e[i]=button:CreateTexture(nil,'OVERLAY'); e[i]:Hide() end
    e[1]:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); e[1]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); e[1]:SetHeight(2)
    e[2]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); e[2]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); e[2]:SetHeight(2)
    e[3]:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); e[3]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); e[3]:SetWidth(2)
    e[4]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); e[4]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); e[4]:SetWidth(2)
    button._ogmTargetCCEdges=e; return e
end
local function refreshTargetCCBorders()
    if not harmful or not harmful.GetChildren then return end
    local ok,kids=pcall(function() return {harmful:GetChildren()} end); if not ok then return end
    for _,b in ipairs(kids) do
        if b and not (b.IsForbidden and b:IsForbidden()) then
            local cat=targetCCCategory(b); local e=b._ogmTargetCCEdges
            if cat then
                e=ensureTargetCCEdges(b)
                local r,g,bl=1,1,1
                if cat=='ROOT' or cat=='SLOW' then r,g,bl=.20,.55,1.00
                elseif cat=='STUN' then r,g,bl=1.00,.10,.10
                elseif cat=='FEAR' or cat=='INCAP' then r,g,bl=1.00,.82,.15
                elseif cat=='SILENCE' or cat=='DISARM' then r,g,bl=.65,.30,1.00 end
                for i=1,4 do e[i]:SetColorTexture(r,g,bl,1); e[i]:Show() end
            elseif e then for i=1,4 do e[i]:Hide() end end
        end
    end
end
local function theme()
    local p=Addon.db and Addon.db.profile
    return p and p.themes and p.themes[(p.godmodeAutoFitEnabled and 'godmode_autofit') or 'auras']
end
local function fontPath(t)
    if t and t.font and LibStub then
        local ok,lsm=pcall(LibStub,'LibSharedMedia-3.0')
        if ok and lsm and lsm.Fetch then return lsm:Fetch('font',t.font) or STANDARD_TEXT_FONT end
    end
    return STANDARD_TEXT_FONT
end


local function styleNativeSwipe(button)
    local a=auraText()
    if not a or not a.ApplyNativeAuraSwipe then return end
    a:ApplyNativeAuraSwipe(button)
end

-- Apply the same Buffs & Debuffs theme as the existing duration text binding.
-- This path runs only when the actual aura button is initialized; no UNIT_AURA
-- sweep, camera/nameplate work, timers, or secret-value branching.
local function bindNativeSwipe(button)
    if button._ogmNativeSwipe then
        styleNativeSwipe(button)
        return
    end
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button)
    cd:SetFrameLevel(button:GetFrameLevel()+1)
    cd.noCooldownCount=true
    cd.noOCC=true -- GODMODE owns the separate aura text; never generate native cooldown numbers
    cd:SetHideCountdownNumbers(true)
    button._ogmNativeSwipe=cd
    -- Bind to the real CustomAuraButton duration provider, not a generic
    -- SetCooldown method (which is not the AuraKit duration attachment API).
    local attached=false
    if type(button.SetDurationCooldown)=='function' then
        attached=pcall(button.SetDurationCooldown,button,cd)
    end
    if not attached then cd:Hide() end
    styleNativeSwipe(button)
end

-- Native application-count binding. Blizzard owns the stack value, including
-- secret combat auras; addon code never reads or branches on that value.
-- Created only in initializeFrame, never in UNIT_AURA/nameplate hot paths.

-- Native AuraButton application count: bound once when the aura button is initialized.
-- The game engine updates the FontString, including secret combat counts.
local function ogmAttachNativeStackCount(button)
    if not button or button._ogmNativeStackCount then return end
    if type(button.SetApplicationCount) ~= 'function' then return end
    local layer = CreateFrame('Frame', nil, button)
    layer:SetAllPoints(button)
    layer:SetFrameLevel(button:GetFrameLevel() + 12)
    layer:EnableMouse(false)
    local font = layer:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
    font:ClearAllPoints()
    font:SetPoint('BOTTOMRIGHT', layer, 'BOTTOMRIGHT', -2, 2)
    font:SetJustifyH('RIGHT')
    font:SetJustifyV('BOTTOM')
    font:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 12, 'OUTLINE')
    font:SetTextColor(1, 1, 1, 1)
    font:SetShadowOffset(1, -1)
    local ok = pcall(button.SetApplicationCount, button, font, {})
    if ok then
        button._ogmNativeStackCount = font
        button._ogmNativeStackLayer = layer
    else
        layer:Hide()
    end
end

local function ogmBindNativeAuraStacks(button)
    ogmAttachNativeStackCount(button)
end

local function init(button,kind)
    local iconSize,textSize=sizes(kind); local t=theme() or {}
    local af=Addon.db and Addon.db.profile and Addon.db.profile.godmodeAutoFitEnabled
    if af then textSize=math.max(1, math.min(15, 5 + 10 * (math.max(0,math.min(99,tonumber(t.fontSize) or 99))/99), (tonumber(iconSize) or 16)-4)) end
    button:SetSize(iconSize,iconSize); pcall(button.SetMouseClickEnabled,button,false)
    local icon=button:CreateTexture(nil,'ARTWORK'); icon:SetAllPoints(button); icon:SetTexCoord(.10,.90,.10,.90)
    -- No forced GODMODE black frame: keep the clean Blizzard icon edge.
    pcall(button.SetIcon,button,icon)
    ogmBindNativeAuraStacks(button)
    -- Install swipe only AFTER the CustomAuraButton icon is registered.
    bindNativeSwipe(button)
    local a=auraText()
    if kind=='BUFF' then
        -- Helpful auras do not have a Blizzard dispel-type color. Give BUFFS the
        -- same full-icon framed treatment as DEBUFFS, using a neutral GODMODE edge.
        -- Anchor to the actual button bounds so resizing never leaves a partial border.
        -- Four straight edge strips: unlike UI-ActionButton-Border this does not
        -- contain a circular/ring-shaped center. The frame follows the exact square
        -- outer edge of the aura icon at every configured icon size.
        local function edge()
            local t=button:CreateTexture(nil,'OVERLAY')
            t:SetColorTexture(0.28,0.20,0.08,0.88)
            return t
        end
        local bt,bb,bl,br=edge(),edge(),edge(),edge()
        bt:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); bt:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); bt:SetHeight(1)
        bb:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); bb:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); bb:SetHeight(1)
        bl:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); bl:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); bl:SetWidth(1)
        br:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); br:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); br:SetWidth(1)
    end
    if kind=='DEBUFF' and (not a or not a.GetInheritBlizzardDebuffBorder or a:GetInheritBlizzardDebuffBorder()) and button.AddDispelTypeTexture then
        local border=button:CreateTexture(nil,'OVERLAY'); border:ClearAllPoints(); border:SetPoint('TOPLEFT',button,'TOPLEFT',-4,4); border:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',4,-4); border:SetScale(1.0)
        local E=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
        local style=E and E.Border
        if style ~= nil then pcall(button.AddDispelTypeTexture,button,border,{style=style,showWhenHarmful=true,showWhenHelpful=false,showWithoutDispelType=true,customDispelColorMap={Magic=CreateColor(0.20,0.60,1.00,1),Poison=CreateColor(0.25,0.85,0.20,1),Curse=CreateColor(0.65,0.25,0.85,1),Disease=CreateColor(0.80,0.65,0.20,1),Bleed=CreateColor(0.90,0.20,0.20,1),Enrage=CreateColor(0.90,0.30,0.10,1),None=CreateColor(0.90,0.20,0.20,1)}}) end
    end
    local carrier=CreateFrame('Frame',nil,button); carrier:SetAllPoints(button); carrier:SetFrameLevel((button:GetFrameLevel() or 1)+5); carrier:EnableMouse(false)
    local text=carrier:CreateFontString(nil,'OVERLAY','GameFontNormal')
    -- Timer is intentionally INSIDE the icon; no external timer row/gap is needed.
    local point=(a and a.GetFrameCountdownTextAnchor and a:GetFrameCountdownTextAnchor(kind)) or 'BOTTOM'
    local tx,ty=(a and a.GetFrameCountdownTextOffset and a:GetFrameCountdownTextOffset(kind)) or 0,0
    -- The duration binding can leave an icon-sized FontString box behind.
    -- Reset it to content-sized geometry before applying the requested 9-point
    -- anchor, otherwise LEFT can appear correct while RIGHT/corners remain
    -- visually centered/offset.
    if text.SetSize then text:SetSize(0,0) end
    text:ClearAllPoints()
    text:SetPoint(point,button,point,tx or 0,ty or 0)
    local h=(point=='LEFT' or point=='TOPLEFT' or point=='BOTTOMLEFT') and 'LEFT' or ((point=='RIGHT' or point=='TOPRIGHT' or point=='BOTTOMRIGHT') and 'RIGHT' or 'CENTER')
    local v=(point=='TOP' or point=='TOPLEFT' or point=='TOPRIGHT') and 'TOP' or ((point=='BOTTOM' or point=='BOTTOMLEFT' or point=='BOTTOMRIGHT') and 'BOTTOM' or 'MIDDLE')
    text:SetJustifyH(h); text:SetJustifyV(v)
    text:SetFont(fontPath(t),textSize,t.fontFlags or 'OUTLINE')
    if t.color and Addon.CreateColor then local cc=Addon.CreateColor(t.color); if cc then text:SetTextColor(cc:GetRGBA()) end end
    if t.shadowColor and Addon.CreateColor then local c=Addon.CreateColor(t.shadowColor); if c then text:SetShadowColor(c:GetRGBA()) end end
    text:SetShadowOffset(tonumber(t.shadowX) or 0,tonumber(t.shadowY) or 0); text:SetJustifyH('CENTER')
    local rules=Addon.db and Addon.db.profile and Addon.db.profile.rules
    local pr=rules and rules.godmode_player_frame
    local showText = not a or not a.GetFrameCountdownTextEnabled or a:GetFrameCountdownTextEnabled(kind)
    if showText and (not pr or pr.enabled ~= false) and Addon.GODMODEDurationBinding and Addon.GODMODEDurationBinding.Bind then
        Addon.GODMODEDurationBinding:Bind(button,text,{themeID='auras'})
        -- DurationBinding can reset FontString geometry while attaching its updater.
        -- Apply the shared Player/Target aura anchor AFTER binding as the final owner.
        text:ClearAllPoints()
        text:SetPoint(point,button,point,tx or 0,ty or 0)
        text:SetJustifyH(h)
        text:SetJustifyV(v)
    else
        text:SetText(''); text:Hide()
    end
end
local function flow(c)
    -- TOP placement grows away from the unit frame, including subsequent rows.
    -- Keep horizontal growth to the right for both placements.
    local a=auraText()
    local top=a and a.GetFrameAuraPlacement and a:GetFrameAuraPlacement('TARGET')=='TOP'
    local anchor=top and 'BOTTOMLEFT' or 'TOPLEFT'
    c:SetSize(1,1)
    local FD=AnchorUtil and AnchorUtil.FlowDirection
    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,anchor) end
    if c.SetFlowLayoutGrowthDirection and FD and FD.Right then
        local vertical
        if top then vertical=FD.Up else vertical=FD.Down end
        if vertical then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,vertical) end
    end
end
-- One shared SELF + TARGET aura blacklist. The existing "Never show spell IDs"
-- field is the single source of truth for both compact unit-frame aura rows.
local function sharedFrameBlacklist()
    local src = _G.OmniCC_GODMODE_ForeverSelfCooldownsDB
    local out = {}
    for token in tostring(src and src.customBlock or ''):gmatch('%d+') do
        local id=tonumber(token); if id then out[id]=true end
    end
    return next(out) and out or nil
end

local function make(kind)
    local iconSize=sizes(kind); serial=serial+1
    local c=CreateFrame('AuraContainer',nil,root,'CustomAuraContainerTemplate'); flow(c)
    -- TARGET can become secret/forbidden as soon as its provider generates aura buttons.
    -- Finish every layout mutation BEFORE AddAuraGroup/SetUnit, unlike the broken path.
    if c.SetFlowLayoutMaximumLineSize then pcall(c.SetFlowLayoutMaximumLineSize,c,ROW*iconSize+(ROW-1)*GAP) end
    local filter=kind=='DEBUFF' and 'HARMFUL' or 'HELPFUL'
    local max=kind=='DEBUFF' and MAX_DEBUFFS or MAX_BUFFS
    local ok=pcall(c.AddAuraGroup,c,'ogm_target_'..kind:lower()..'_'..serial,filter,{maxFrameCount=max,candidateFilters={excludeSpellIDs=sharedFrameBlacklist()},initializeFrame=function(b) init(b,kind) end,layout={elementWidth=iconSize,elementHeight=iconSize,elementSpacing=GAP,lineSpacing=ROW_GAP}})
    if not ok then c:Hide(); return nil end
    -- AddAuraGroup can reset the secure flow layout: reapply the selected direction.
    flow(c)
    local a=auraText(); local enabled = not (a and a.GetFrameAuraEnabled) or a:GetFrameAuraEnabled('TARGET',kind)
    c._ogmTargetEnabled=enabled
    return c
end
local function retire(c)
    if not c then return end
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    if c.SetUnit then pcall(c.SetUnit,c,nil) end
    pcall(c.Hide,c)
end
local function positionGroups()
    if not helpful or not harmful then return end
    if InCombatLockdown and InCombatLockdown() then return end
    helpful:ClearAllPoints(); harmful:ClearAllPoints()
    local a=auraText()
    local bx,by,swap=0,0,false
    local dx,dy=0,0
    if a and a.GetFrameAuraLayout then
        bx,by,swap=a:GetFrameAuraLayout('TARGET','BUFF')
        dx,dy=a:GetFrameAuraLayout('TARGET','DEBUFF')
    end
    -- Anchor the first group nearest the frame on TOP placement, and
    -- use the original downward geometry on BOTTOM placement.
    local top=a and a.GetFrameAuraPlacement and a:GetFrameAuraPlacement('TARGET')=='TOP'
    local first=swap and harmful or helpful
    local second=swap and helpful or harmful
    local fx,fy=swap and dx or bx,swap and dy or by
    local sx,sy=swap and bx or dx,swap and by or dy
    if top then
        first:SetPoint('BOTTOMLEFT',root,'BOTTOMLEFT',fx,fy)
        second:SetPoint('BOTTOMLEFT',first,'TOPLEFT',sx,sy)
    else
        first:SetPoint('TOPLEFT',root,'TOPLEFT',fx,fy)
        second:SetPoint('TOPLEFT',first,'BOTTOMLEFT',sx,sy)
    end
end
local function rebuild()
    if InCombatLockdown and InCombatLockdown() then return false end
    if not root then return false end
    local nh,nd=make('BUFF'),make('DEBUFF'); if not nh or not nd then retire(nh); retire(nd); return false end
    local oh,od=helpful,harmful; helpful,harmful=nh,nd
    -- Same SELF geometry, but crucially complete it while TARGET containers are still unbound.
    positionGroups()
    helpful:SetUnit('target'); harmful:SetUnit('target')
    pcall(helpful.SetEnabled,helpful,helpful._ogmTargetEnabled); helpful:SetShown(helpful._ogmTargetEnabled)
    pcall(harmful.SetEnabled,harmful,harmful._ogmTargetEnabled); harmful:SetShown(harmful._ogmTargetEnabled)
    retire(oh); retire(od); built=true
    if helpful.UpdateAllAuras then pcall(helpful.UpdateAllAuras,helpful) end
    if harmful.UpdateAllAuras then pcall(harmful.UpdateAllAuras,harmful) end
    C_Timer.After(0,refreshTargetCCBorders)
    suppressBlizzardTargetAuraText()
    C_Timer.After(.05,suppressBlizzardTargetAuraText)
    return true
end
local pendingRebuild=false
local function request()
    applyToken=applyToken+1; local token=applyToken
    if InCombatLockdown and InCombatLockdown() then
        pendingRebuild=true
        return
    end
    C_Timer.After(.12,function()
        if token~=applyToken then return end
        if InCombatLockdown and InCombatLockdown() then
            pendingRebuild=true
            return
        end
        if rebuild() then pendingRebuild=false end
    end)
end
local function reposition()
    if not root then return end
    local pf=_G.TargetFrame; if not pf then return end
    local a=auraText(); local x,y=0,0; if a and a.GetTargetFrameOffset then x,y=a:GetTargetFrameOffset() end
    if InCombatLockdown and InCombatLockdown() then return end
    local placement=a and a.GetFrameAuraPlacement and a:GetFrameAuraPlacement('TARGET') or 'BOTTOM'
    root:ClearAllPoints()
    -- Keep the same TargetFrame BOTTOMLEFT horizontal reference for both
    -- placements. Only the vertical attachment changes; switching TOP must
    -- never introduce a second horizontal positioning path.
    local horizontalOffset=23+x
    if placement=='TOP' then
        root:SetPoint('BOTTOMLEFT',pf,'BOTTOMLEFT',horizontalOffset,(pf:GetHeight() or 0)-27+y)
    else
        root:SetPoint('TOPLEFT',pf,'BOTTOMLEFT',horizontalOffset,27+y)
    end
    positionGroups()
end
local function build()
    if built then return true end
    if InCombatLockdown and InCombatLockdown() then return false end
    local pf=_G.TargetFrame; if not pf then return false end
    suppressBlizzardTargetAuraText()
    root=CreateFrame('Frame','OmniCC_GODMODE_TargetFrameAuraAnchor',pf); root:SetSize(1,1)
    -- Same approved below-frame geometry used by TargetFrame.
    reposition()
    -- Preserve the player's aura placement while reducing its visual priority.
    -- Do not modify or reposition the Blizzard/TPerl cast bar.
    root:SetFrameLevel((pf:GetFrameLevel() or 1)+2); root:Show()
    return rebuild()
end
Addon.ForeverTargetAuraTimers={Build=build,Apply=request,ApplyTheme=request,RequestApply=request,PositionGroups=positionGroups,Reposition=reposition}
Addon.ForeverNativeTargetAuras=Addon.ForeverTargetAuraTimers
if hooksecurefunc and _G.TargetFrame_UpdateAuras then
    hooksecurefunc('TargetFrame_UpdateAuras', function() C_Timer.After(0, suppressBlizzardTargetAuraText) end)
end
local f=CreateFrame('Frame'); f:RegisterEvent('PLAYER_LOGIN'); f:RegisterEvent('PLAYER_ENTERING_WORLD'); f:RegisterEvent('PLAYER_TARGET_CHANGED'); f:RegisterUnitEvent('UNIT_AURA','target'); f:RegisterEvent('PLAYER_REGEN_ENABLED')
f:SetScript('OnEvent',function(_,event,unit)
    if event == 'UNIT_AURA' then
        if unit=='target' then C_Timer.After(0,refreshTargetCCBorders) end
        return
    end
    if event == 'PLAYER_REGEN_ENABLED' and pendingRebuild then
        pendingRebuild=false
        request()
        return
    end
    if event == 'PLAYER_TARGET_CHANGED' and built then
        -- The unit token remains "target" even when its identity changes. Force the
        -- two already-bound secure AuraContainers to consume the new target now;
        -- rebuilding them through the old .12/.30 second timers caused the visible lag.
        if helpful and helpful.UpdateAllAuras then pcall(helpful.UpdateAllAuras,helpful) end
        if harmful and harmful.UpdateAllAuras then pcall(harmful.UpdateAllAuras,harmful) end
        C_Timer.After(0,refreshTargetCCBorders)
        suppressBlizzardTargetAuraText()
        return
    end
    C_Timer.After(.3,function() if not built then build() else request() end end)
end)
