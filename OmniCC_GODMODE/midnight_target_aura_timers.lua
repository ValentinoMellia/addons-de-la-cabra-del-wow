-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface == 16001 then return end
local _, Addon = ...

-- Forever TargetFrame aura owner.
-- IMPORTANT: never touch Blizzard TargetFrameBuff/TargetFrameDebuff objects:
-- Forever can mark those frames forbidden.  Instead our secure AuraContainers
-- bind to unit="target" and are drawn at Blizzard's native aura origin, above
-- the native artwork.  This follows the safe AuraContainer lifecycle used by
-- current unit-frame addons: declare groups first, SetUnit LAST, then force one
-- UpdateAllAuras so a target change can never retain the previous unit's icons.
local root, helpful, harmful
local built=false
local records={BUFF={},DEBUFF={}}
local MAX_BUFFS,MAX_DEBUFFS=18,18
local GAP=0
local ROW=6
local ROW_GAP=0 -- exact Forever parity: icons touch; timers stay inside

-- GODMODE replaces Blizzard's TargetFrame aura display. Blizzard's own
-- TargetFrame_UpdateAuras honors these limits without us touching any
-- protected TargetFrameBuff/TargetFrameDebuff button.
local function suppressBlizzardTargetAuras()
    local tf=_G.TargetFrame
    if not tf then return end
    tf.maxBuffs=0
    tf.maxDebuffs=0
end

local function frameAuraEnabled(kind)
    local a=Addon and Addon.MidnightAuraText
    if a and a.GetFrameAuraEnabled then
        return a:GetFrameAuraEnabled('TARGET', kind)
    end
    return true
end

local function vals(kind)
    local a=Addon and Addon.MidnightAuraText
    local icon=(a and a.GetScopedIconSize and a:GetScopedIconSize('TARGET',kind)) or 21
    local text=(a and a.GetScopedTextSize and a:GetScopedTextSize('TARGET',kind)) or 10
    return tonumber(icon) or 21, tonumber(text) or 10
end

local function styleText(text,kind)
    if not text then return end
    local _,textSize=vals(kind)
    -- Never READ font state from AuraContainer descendants on Midnight: the
    -- provider can mark them forbidden immediately. Apply a known font blindly.
    pcall(text.SetFont,text,STANDARD_TEXT_FONT,textSize,'OUTLINE')
    pcall(text.SetJustifyH,text,'CENTER'); pcall(text.SetJustifyV,text,'MIDDLE')
end

local function targetTheme(kind)
    local p=Addon.db and Addon.db.profile
    local id='auras'
    return p and p.themes and p.themes[id]
end
local function themeFont(t)
    if t and t.font and LibStub then
        local ok,lsm=pcall(LibStub,'LibSharedMedia-3.0')
        if ok and lsm and lsm.Fetch then return lsm:Fetch('font',t.font) or STANDARD_TEXT_FONT end
    end
    return STANDARD_TEXT_FONT
end


-- Apply the Buffs & Debuffs appearance directly to the cooldown created by
-- this secure aura renderer, before the provider seals its aura button.
local function applyNativeAuraSwipe(cd)
    local p=Addon and Addon.db and Addon.db.profile
    local t=p and p.themes and p.themes.auras
    if not t or not cd then return end
    local function on(v,default)
        if v=='always' or v==true then return true end
        if v=='never' or v==false then return false end
        return default
    end
    local enabled=t.themeCooldown~=false
    if cd.SetDrawSwipe then cd:SetDrawSwipe(enabled and on(t.drawSwipe,true)) end
    if cd.SetDrawEdge then cd:SetDrawEdge(enabled and on(t.drawEdge,false)) end
    if cd.SetDrawBling then cd:SetDrawBling(enabled and on(t.drawBling,false)) end
    if cd.SetReverse then cd:SetReverse(enabled and on(t.reverse,false)) end
    if t.themeSwipeColor and t.swipeColor and Addon.HexToRGBA and cd.SetSwipeColor then
        local ok,r,g,b,a=pcall(Addon.HexToRGBA,t.swipeColor)
        if ok and r then cd:SetSwipeColor(r,g,b,a or 1) end
    end
end


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

-- Target cooldown text is owned by the custom AuraContainer buttons.  A menu
-- change must update these live fontstrings, not just re-anchor the containers.
local targetCountdownLabels=setmetatable({}, {__mode='k'})
local function refreshCountdownAnchors()
    local controls=Addon and Addon.MidnightAuraText
    for label,entry in pairs(targetCountdownLabels) do
        if label and entry and entry.button then
            local kind=entry.kind
            local theme=targetTheme(kind) or {}
            local point=(controls and controls.GetFrameCountdownTextAnchor and controls:GetFrameCountdownTextAnchor(kind)) or theme.point or 'BOTTOM'
            local x,y=0,0
            if controls and controls.GetFrameCountdownTextOffset then x,y=controls:GetFrameCountdownTextOffset(kind)
            else x=tonumber(theme.offsetX) or 0; y=tonumber(theme.offsetY) or 0 end
            -- Midnight may mark Blizzard AuraContainer descendants forbidden after
            -- initialization. Never attempt to move or restyle such FontStrings:
            -- doing so taints the secure aura path and raises a Lua error.
            local safe = true
            if label.IsForbidden then
                local ok, forbidden = pcall(label.IsForbidden, label)
                safe = ok and not forbidden
            end
            if safe then
                local ok = pcall(function()
                    label:ClearAllPoints()
                    label:SetPoint(point,entry.carrier,point,tonumber(x) or 0,tonumber(y) or 0)
                    local _,requestedSize=vals(kind)
                    label:SetFont(themeFont(theme),tonumber(requestedSize) or 8,theme.fontFlags or 'OUTLINE')
                    if theme.color and Addon.CreateColor then
                        local c=Addon.CreateColor(theme.color)
                        if c then label:SetTextColor(c:GetRGBA()) end
                    end
                    if theme.shadowColor and Addon.CreateColor then
                        local c=Addon.CreateColor(theme.shadowColor)
                        if c then label:SetShadowColor(c:GetRGBA()) end
                    end
                    label:SetShadowOffset(tonumber(theme.shadowX) or 0,tonumber(theme.shadowY) or 0)
                    label:SetJustifyH('CENTER'); label:SetJustifyV('MIDDLE')
                end)
                if not ok then targetCountdownLabels[label] = nil end
            else
                targetCountdownLabels[label] = nil
            end
        end
    end
end

local function init(button,kind)
    -- AuraKit-safe creation window: everything parented to the provider button is
    -- created and bound HERE. After initializeFrame returns we never touch the
    -- button or any descendant again (Midnight secure-aura taint rule).
    local iconSize=vals(kind)
    button:SetSize(iconSize,iconSize)
    pcall(button.SetMouseClickEnabled,button,false)

    local icon=button:CreateTexture(nil,'ARTWORK')
    icon:SetAllPoints(button)
    icon:SetTexCoord(.10,.90,.10,.90)
    button:SetIcon(icon)
    ogmAttachNativeStackCount(button)

    -- Blizzard-native debuff type border (Magic/Poison/Curse/Disease) created
    -- only during the secure AuraContainer initialize window.
    local at=Addon and Addon.MidnightAuraText
    if kind=='BUFF' then
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
    if kind=='DEBUFF' and (not at or not at.GetInheritBlizzardDebuffBorder or at:GetInheritBlizzardDebuffBorder()) and button.AddDispelTypeTexture then
        local border=button:CreateTexture(nil,'OVERLAY',nil,7)
        border:ClearAllPoints()
        -- Keep the dispel/type border on the TRUE outer edge of the icon. Points
        -- are relative to the aura button, so the border automatically follows
        -- every icon-size change instead of remaining a small box in the middle.
        border:SetPoint('TOPLEFT',button,'TOPLEFT',-4,4)
        border:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',4,-4)
        if border.SetSnapToPixelGrid then pcall(border.SetSnapToPixelGrid,border,true) end
        if border.SetTexelSnappingBias then pcall(border.SetTexelSnappingBias,border,0) end
        local E=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
        local style=E and E.Border
        if style ~= nil then
            pcall(button.AddDispelTypeTexture,button,border,{style=style,showWhenHarmful=true,showWhenHelpful=false,showWithoutDispelType=true,customDispelColorMap={Magic=CreateColor(0.20,0.60,1.00,1),Poison=CreateColor(0.25,0.85,0.20,1),Curse=CreateColor(0.65,0.25,0.85,1),Disease=CreateColor(0.80,0.65,0.20,1),Bleed=CreateColor(0.90,0.20,0.20,1),Enrage=CreateColor(0.90,0.30,0.10,1),None=CreateColor(0.90,0.20,0.20,1)}})
        end
    end

    -- Exactly like the working AuraKit pattern: give the AuraButton its OWN
    -- cooldown while access is legal. Do not ask OmniCC to inspect the button later.
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    applyNativeAuraSwipe(cd)
    cd.OGMTargetAuraNativeSuppressed=true
    cd.noCooldownCount=true
    cd.noOCC=true -- GODMODE owns the separate aura text; never generate native cooldown numbers
    cd:SetHideCountdownNumbers(true) -- never allow OmniCC/Blizzard text inside the icon; GODMODE text below is the single timer
    button:SetDurationCooldown(cd)

    local carrier=CreateFrame('Frame',nil,button)
    carrier:SetAllPoints(button)
    carrier:SetFrameLevel((button:GetFrameLevel() or 1)+8)
    carrier:EnableMouse(false)
    local text=carrier:CreateFontString(nil,'OVERLAY','GameFontNormal')
    local t=targetTheme(kind) or {}
    local point=(a and a.GetFrameCountdownTextAnchor and a:GetFrameCountdownTextAnchor(kind)) or t.point or 'BOTTOM'; local ox,oy=0,0; if a and a.GetFrameCountdownTextOffset then ox,oy=a:GetFrameCountdownTextOffset(kind) else ox=tonumber(t.offsetX) or 0; oy=tonumber(t.offsetY) or 0 end
    if oy==nil then oy=-10 end
    text:SetPoint(point,carrier,point,ox,oy)
    local _,textSize=vals(kind)
    text:SetFont(themeFont(t),textSize,t.fontFlags or 'OUTLINE')
    if t.color and Addon.CreateColor then local cc=Addon.CreateColor(t.color); if cc then text:SetTextColor(cc:GetRGBA()) end end
    if t.shadowColor and Addon.CreateColor then local c=Addon.CreateColor(t.shadowColor); if c then text:SetShadowColor(c:GetRGBA()) end end
    text:SetShadowOffset(tonumber(t.shadowX) or 0,tonumber(t.shadowY) or 0)
    text:SetJustifyH('CENTER'); text:SetJustifyV('MIDDLE')
    local at=Addon and Addon.MidnightAuraText
    local showText = not at or not at.GetFrameCountdownTextEnabled or at:GetFrameCountdownTextEnabled(kind)
    local binder=Addon and Addon.GODMODEDurationBinding
    if showText and binder and binder.Bind then
        binder:Bind(button,text,{themeID='auras'})
        targetCountdownLabels[text]={button=button,carrier=carrier,kind=kind}
    else
        text:SetText(''); text:Hide()
    end
end

local function flow(c)
    -- Match the target placement with the secure aura layout's row growth.
    -- This runs before AddAuraGroup / SetUnit, never on forbidden aura buttons.
    local at=Addon and Addon.MidnightAuraText
    local tf=_G.TargetFrame
    local top=at and at.GetFrameAuraPlacement and at:GetFrameAuraPlacement('TARGET')=='TOP'
        or (not (at and at.GetFrameAuraPlacement) and tf and tf.buffsOnTop and true or false)
    local anchor=top and 'BOTTOMLEFT' or 'TOPLEFT'
    local FD=AnchorUtil and AnchorUtil.FlowDirection
    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,anchor) end
    if c.SetFlowLayoutGrowthDirection and FD and FD.Right then
        local vertical
        if top then vertical=FD.Up else vertical=FD.Down end
        if vertical then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,vertical) end
    end
end

local function position()
    if not root or not helpful or not harmful then return end
    local tf=_G.TargetFrame
    if not tf then return end

    -- Mirror Blizzard TargetFrame_UpdateAuras/TargetFrame_Update*Anchor EXACTLY.
    -- Edit Mode's "Buffs On Top" sets TargetFrame.buffsOnTop. Blizzard then
    -- flips the aura origin from below the frame to above it. Our independent
    -- AuraContainers follow that SAME frame property, so moving/changing the
    -- Target Frame in Edit Mode also moves/flips GODMODE auras with it.
    local at=Addon and Addon.MidnightAuraText
    local onTop = at and at.GetFrameAuraPlacement and at:GetFrameAuraPlacement('TARGET')=='TOP' or (not (at and at.GetFrameAuraPlacement) and tf.buffsOnTop and true or false)
    local ax,ay=0,0
    if at and at.GetTargetFrameOffset then ax,ay=at:GetTargetFrameOffset() end
    root:ClearAllPoints()
    if onTop then
        local startY=-18
        local threat=tf.threatNumericIndicator
        if threat and threat.IsShown and threat:IsShown() and threat.GetHeight then
            startY=startY+(threat:GetHeight() or 0)
        end
        root:SetPoint('BOTTOMLEFT',tf,'BOTTOMLEFT',23+ax,(tf:GetHeight() or 0)+startY+ay)
    else
        root:SetPoint('TOPLEFT',tf,'BOTTOMLEFT',23+ax,27+ay)
    end

    local bx,by,swap=0,0,false; local dx,dy=0,0
    if at and at.GetFrameAuraLayout then
        bx,by,swap=at:GetFrameAuraLayout('TARGET','BUFF')
        dx,dy=at:GetFrameAuraLayout('TARGET','DEBUFF')
    else
        swap=UnitExists('target') and UnitCanAttack('player','target') and true or false
    end
    local first=swap and harmful or helpful
    local second=swap and helpful or harmful
    local fx,fy=swap and dx or bx,swap and dy or by
    local sx,sy=swap and bx or dx,swap and by or dy
    helpful:ClearAllPoints(); harmful:ClearAllPoints()
    if onTop then
        first:SetPoint('BOTTOMLEFT',root,'BOTTOMLEFT',fx,fy)
        second:SetPoint('BOTTOMLEFT',first,'TOPLEFT',sx,sy+3)
    else
        first:SetPoint('TOPLEFT',root,'TOPLEFT',fx,fy)
        second:SetPoint('TOPLEFT',first,'BOTTOMLEFT',sx,sy-3)
    end
end

local function refreshTarget()
    refreshCountdownAnchors()
    if not built then return end
    suppressBlizzardTargetAuras()
    position()
    -- Critical: SetUnit alone can leave the previous generated button set until
    -- the next secure aura event.  Force a full secure refresh on target swap.
    if helpful and helpful.UpdateAllAuras then pcall(helpful.UpdateAllAuras,helpful) end
    if harmful and harmful.UpdateAllAuras then pcall(harmful.UpdateAllAuras,harmful) end
end

local rebuildQueued=false
local rebuildSerial=0

-- One shared SELF + TARGET aura blacklist. The existing "Never show spell IDs"
-- field is the single source of truth for both compact unit-frame aura rows.
local function sharedFrameBlacklist()
    local src = _G.OmniCC_GODMODE_MidnightSelfCooldownsDB
    local out = {}
    for token in tostring(src and src.customBlock or ''):gmatch('%d+') do
        local id=tonumber(token); if id then out[id]=true end
    end
    return next(out) and out or nil
end

local function makeContainer(kind)
    local iconSize=vals(kind)
    local c=CreateFrame('AuraContainer',nil,root,'CustomAuraContainerTemplate')
    c:SetSize(1,1); flow(c)
    local filter=kind=='DEBUFF' and 'HARMFUL' or 'HELPFUL'
    local max=kind=='DEBUFF' and MAX_DEBUFFS or MAX_BUFFS
    local ok=pcall(c.AddAuraGroup,c,'ogm_native_target_'..kind:lower()..'_'..rebuildSerial,filter,{
        maxFrameCount=max,candidateFilters={excludeSpellIDs=sharedFrameBlacklist()},
        initializeFrame=function(b) init(b,kind) end,
        layout={elementWidth=iconSize,elementHeight=iconSize,elementSpacing=GAP,lineSpacing=ROW_GAP}
    })
    if not ok then c:Hide(); return nil end
    -- AddAuraGroup can reset the secure flow layout: reapply the selected direction.
    flow(c)
    local width=(ROW*iconSize)+((ROW-1)*GAP)
    if c.SetFlowLayoutMaximumLineSize then pcall(c.SetFlowLayoutMaximumLineSize,c,width) end
    c:SetUnit('target')
    -- Keep both independent providers enabled. On Midnight, SetEnabled(false) on
    -- one Target AuraContainer can tear down the shared target aura provider and
    -- make the other (BUFF/DEBUFF) disappear too. Visibility is therefore owned
    -- per container with alpha only; the two switches stay truly independent.
    pcall(c.SetEnabled,c,true)
    c:Show()
    c:SetAlpha(frameAuraEnabled(kind) and 1 or 0)
    return c
end

local function rebuildContainers()
    if not root then return false end
    if InCombatLockdown and InCombatLockdown() then rebuildQueued=true; return false end
    rebuildSerial=rebuildSerial+1
    local oldH,oldD=helpful,harmful
    local nh=makeContainer('BUFF')
    local nd=makeContainer('DEBUFF')
    if not (nh and nd) then
        if nh then nh:Hide() end; if nd then nd:Hide() end
        return false
    end
    helpful,harmful=nh,nd
    -- Retire old secure containers completely. Hidden AuraContainers still receive
    -- aura updates if left enabled/unit-bound; repeated slider rebuilds then stack
    -- invisible providers and cause the huge FPS lag.
    local function retire(c)
        if not c then return end
        if c.SetEnabled then pcall(c.SetEnabled,c,false) end
        if c.SetUnit then pcall(c.SetUnit,c,nil) end
        pcall(c.Hide,c)
    end
    retire(oldH); retire(oldD)
    -- Both providers must refresh NOW. In particular HARMFUL used to remain at
    -- the old geometry on the current NPC until the next target/aura event.
    if helpful and helpful.UpdateAllAuras then pcall(helpful.UpdateAllAuras,helpful) end
    if harmful and harmful.UpdateAllAuras then pcall(harmful.UpdateAllAuras,harmful) end
    position(); refreshTarget()
    return true
end

local function apply()
    -- TARGET Buff/Debuff switches own these two visible secure containers.
    -- Toggle the CONTAINERS, never their generated aura children (which become
    -- forbidden on Midnight). This makes TARGET Buffs and TARGET Debuffs truly
    -- independent and updates immediately without rebuilding geometry.
    local buffOn=frameAuraEnabled('BUFF')
    local debuffOn=frameAuraEnabled('DEBUFF')
    if helpful then
        if helpful.SetEnabled then pcall(helpful.SetEnabled,helpful,true) end
        pcall(helpful.Show,helpful); pcall(helpful.SetAlpha,helpful,buffOn and 1 or 0)
        if helpful.UpdateAllAuras then pcall(helpful.UpdateAllAuras,helpful) end
    end
    if harmful then
        if harmful.SetEnabled then pcall(harmful.SetEnabled,harmful,true) end
        pcall(harmful.Show,harmful); pcall(harmful.SetAlpha,harmful,debuffOn and 1 or 0)
        if harmful.UpdateAllAuras then pcall(harmful.UpdateAllAuras,harmful) end
    end
    position(); refreshTarget()
end

local applyToken=0
local function requestApply()
    applyToken=applyToken+1
    local token=applyToken
    C_Timer.After(.12,function()
        if token~=applyToken then return end
        if InCombatLockdown and InCombatLockdown() then rebuildQueued=true; return end
        rebuildContainers()
    end)
end

local function build()
    if built or (InCombatLockdown and InCombatLockdown()) then return built end
    local tf=_G.TargetFrame; if not tf then return false end
    suppressBlizzardTargetAuras()
    root=CreateFrame('Frame','OmniCC_GODMODE_NativeTargetAuraAnchor',tf)
    -- Lower GODMODE aura priority without moving or modifying the target cast bar.
    root:SetSize(1,1); root:SetFrameStrata(tf:GetFrameStrata()); root:SetFrameLevel((tf:GetFrameLevel() or 1)+2); root:Show()
    rebuildSerial=rebuildSerial+1
    helpful=makeContainer('BUFF'); harmful=makeContainer('DEBUFF')
    built=helpful~=nil and harmful~=nil
    if not built then root:Hide(); return false end
    position(); refreshTarget()
    return true
end

Addon.MidnightNativeTargetAuras={RefreshThemeAppearance=refreshCountdownAnchors,RefreshTextAppearance=refreshCountdownAnchors,Build=build,Apply=apply,ApplyTheme=requestApply,RequestApply=requestApply,ApplyThemeNow=rebuildContainers,Refresh=refreshTarget,Reposition=position}
-- Keep the established Midnight bridge API so every existing menu/compat caller
-- drives this new visible GODMODE TargetFrame owner without changing other systems.
Addon.MidnightTargetAuraTimers=Addon.MidnightTargetAuraTimers or {}
Addon.MidnightTargetAuraTimers.RefreshThemeAppearance=refreshCountdownAnchors
Addon.MidnightTargetAuraTimers.RefreshTextAppearance=refreshCountdownAnchors
Addon.MidnightTargetAuraTimers.Build=build
Addon.MidnightTargetAuraTimers.Apply=apply
Addon.MidnightTargetAuraTimers.ApplyTheme=requestApply
Addon.MidnightTargetAuraTimers.RequestApply=requestApply
Addon.MidnightTargetAuraTimers.ApplyThemeNow=rebuildContainers
Addon.MidnightTargetAuraTimers.ApplyVisibility=apply
Addon.MidnightTargetAuraTimers.RefreshOwnership=apply
Addon.MidnightTargetAuraTimers.SetCompatibilityScopes=function(buffExternal,debuffExternal)
    -- Native Midnight GODMODE TargetFrame remains the owner unless a future
    -- compatibility module explicitly replaces the entire TargetFrame aura UI.
    apply()
end

-- Edit Mode / Blizzard TargetFrame integration. We only re-anchor OUR root;
-- no Blizzard aura button or protected AuraContainer descendant is touched.
if hooksecurefunc and type(_G.TargetFrame_UpdateAuras)=='function' then
    hooksecurefunc('TargetFrame_UpdateAuras',function(frame)
        if built and (frame==_G.TargetFrame or frame==nil) then
            suppressBlizzardTargetAuras()
            position()
        end
    end)
end

local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN'); f:RegisterEvent('PLAYER_TARGET_CHANGED'); f:RegisterEvent('PLAYER_REGEN_ENABLED')
f:SetScript('OnEvent',function(_,event)
    C_Timer.After(event=='PLAYER_TARGET_CHANGED' and 0 or .15,function()
        if not built then build()
        elseif event=='PLAYER_REGEN_ENABLED' and rebuildQueued then rebuildQueued=false; rebuildContainers()
        else apply() end
    end)
end)
