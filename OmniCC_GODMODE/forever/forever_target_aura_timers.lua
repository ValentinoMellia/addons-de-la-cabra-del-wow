local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...
-- The native Forever Target AuraContainer renderer is already installed.
-- Do not install a second competing renderer or overwrite its methods:
-- provide only the compatibility ownership bridge needed by the settings UI.
if Addon and Addon.ForeverNativeTargetAuras then
    local native = Addon.ForeverNativeTargetAuras
    function native.SetCompatibilityScopes(buffExternal, debuffExternal)
        native.compatBuffsExternal = buffExternal and true or false
        native.compatDebuffsExternal = debuffExternal and true or false
        if native.RequestApply then native.RequestApply() end
    end
    -- The settings and TPerl compatibility bridges address this public API.
    -- Alias the actual renderer instead of leaving a dead module reference.
    Addon.ForeverTargetAuraTimers = native
    native.Apply = native.Apply or native.RequestApply
    native.Refresh = native.Refresh or native.RequestApply
    native.ApplyTheme = native.ApplyTheme or native.RequestApply
    native.ApplyVisibility = native.ApplyVisibility or native.RequestApply
    native.Reposition = native.Reposition or native.RequestApply
    return
end
-- Forever 1.60.1 is selected by Interface 16001 above. Do not gate this
-- native TargetFrame timer engine behind WOW_PROJECT_MAINLINE: Forever uses
-- the modern AuraContainer duration API but is not reported as Mainline.

-- Forever 12.1 TargetFrame duration bridge.
-- Aura data stays inside Blizzard's secure CustomAuraContainer pipeline.
-- The duration FontString is anchored to the exact AuraButton only during
-- initializeFrame, before Blizzard applies secret aspects.  Never parent-walk
-- or re-anchor secure buttons later.

local LSM = LibStub and LibStub('LibSharedMedia-3.0', true)
local root, helpfulContainer, harmfulContainer
local built = false
local buildError
local helpfulTexts, harmfulTexts = {}, {}
local compatBuffs, compatDebuffs = false, false

local ICON = 21
local GAP = 0
local TIMER_GAP = 0
local TIMER_W = 30
local TIMER_H = 14
local ROW_GAP = 0
local MAX_HELPFUL = 32
local MAX_HARMFUL = 16

local function getTheme()
    local db = Addon and Addon.db and Addon.db.profile
    local themes = db and db.themes
    return themes and themes.nameplates or nil
end

local function frameAuraEnabled(kind)
    local a=Addon and Addon.ForeverAuraText
    if a and a.GetFrameAuraEnabled then return a:GetFrameAuraEnabled('TARGET',kind) end
    return true
end

local function frameCountdownTextAnchor(kind)
    local a=Addon and Addon.ForeverAuraText
    if a and a.GetFrameCountdownTextAnchor then return a:GetFrameCountdownTextAnchor(kind) end
    return 'BOTTOM'
end

local function frameCountdownTextEnabled(kind)
    local a=Addon and Addon.ForeverAuraText
    if a and a.GetFrameCountdownTextEnabled then return a:GetFrameCountdownTextEnabled(kind) end
    return true
end

-- Typography only.  IMPORTANT: do not touch points/parents here because this
-- function can run after the AuraButton has become a secret/forbidden object.
local function styleText(fs, kind)
    if not fs then return end
    local theme = getTheme()
    -- Do not apply fallback typography before AceDB/profile initialization.
    -- On /reload PLAYER_LOGIN can reach this module before Addon:OnLoad() has
    -- assigned Addon.db; the old fallback size (12) then stayed visible until
    -- the user touched any theme control (Thin/Thick, font, size), which forced
    -- a later Refresh and made the saved value suddenly appear correct.
    if not theme then return end
    local font = STANDARD_TEXT_FONT
    local at=Addon and Addon.ForeverAuraText
    local size = (at and at.GetScopedTextSize and at:GetScopedTextSize('TARGET',kind or 'BUFF')) or tonumber(theme.fontSize) or 12
    local flags = theme.fontFlags ~= nil and theme.fontFlags or 'OUTLINE'
    if theme and theme.font and LSM then
        font = LSM:Fetch('font', theme.font) or font
    end
    local ok = pcall(fs.SetFont, fs, font, size, flags)
    if not ok then pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, flags) end
    pcall(fs.SetJustifyH, fs, 'CENTER')
    pcall(fs.SetJustifyV, fs, 'CENTER')
    pcall(fs.SetShadowOffset, fs, 1, -1)
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 1)
end

local function initButton(button, list, auraPrefix)
    -- Create and bind every secure source button immediately.  Blizzard's
    -- visible TargetFrameBuff/TargetFrameDebuff buttons are created lazily, so
    -- they may NOT exist yet when AddAuraGroup pre-creates this source batch.
    -- The old code returned here and permanently lost the duration binding.
    button:SetSize(1, 1)

    local slot = #list + 1
    local holder = CreateFrame('Frame', nil, TargetFrame)
    holder:SetSize(TIMER_W, TIMER_H)
    holder:SetFrameStrata(TargetFrame:GetFrameStrata())
    holder:SetFrameLevel((TargetFrame:GetFrameLevel() or 1) + 30)
    holder:Hide()

    local fs = holder:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    fs:SetAllPoints(holder)
    fs:SetJustifyH('CENTER')
    fs:SetJustifyV('CENTER')

    local durationEngine = Addon and Addon.GODMODEDurationBinding
    local ok = durationEngine and durationEngine.Bind and durationEngine:Bind(button, fs, {themeID='auras'})
    if not ok then
        buildError = 'GODMODE duration-text binding failed at '..auraPrefix..tostring(slot)
        holder:Hide()
    end

    styleText(fs, auraPrefix == 'Debuff' and 'DEBUFF' or 'BUFF')
    list[#list + 1] = {
        sourceButton = button,
        text = fs,
        holder = holder,
        realButton = nil,
        slot = slot,
        prefix = auraPrefix,
    }
end

local function resolveRealButtons(list, external)
    for _,rec in ipairs(list) do
        local real = _G['TargetFrame' .. rec.prefix .. rec.slot]
        if real and rec.realButton ~= real then
            rec.realButton = real
            rec.holder:ClearAllPoints()
            local kind=rec.prefix == 'Debuff' and 'DEBUFF' or 'BUFF'
            local point=frameCountdownTextAnchor(kind)
            local at=Addon and Addon.ForeverAuraText; local tx,ty=0,0; if at and at.GetFrameCountdownTextOffset then tx,ty=at:GetFrameCountdownTextOffset(kind) end
            rec.holder:SetPoint(point, real, point, tx or 0, ty or 0)
            rec.holder:SetFrameStrata(TargetFrame:GetFrameStrata())
            rec.holder:SetFrameLevel((real:GetFrameLevel() or TargetFrame:GetFrameLevel() or 1) + 30)
        end
        real = rec.realButton
        if real then
            local atSwipe=Addon and Addon.ForeverAuraText
            if atSwipe and atSwipe.ApplyNativeAuraSwipe then atSwipe:ApplyNativeAuraSwipe(real) end
            local cd=real.Cooldown or real.cooldown or real.CooldownFrame or real.cooldownFrame
            if cd then
                cd.OGMTargetAuraNativeSuppressed = not external
                cd.noCooldownCount = external and nil or true
                if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,not external) end
            end
            local kind=rec.prefix == 'Debuff' and 'DEBUFF' or 'BUFF'; rec.holder:SetShown(frameAuraEnabled(kind) and frameCountdownTextEnabled(kind) and (not external) and real:IsShown())
        else
            rec.holder:Hide()
        end
    end
end

local function resolveAllRealButtons()
    resolveRealButtons(helpfulTexts, compatBuffs)
    resolveRealButtons(harmfulTexts, compatDebuffs)
end

local function makeGroup(container, key, filter, maxCount, list, auraPrefix)
    local layout = {
        elementWidth = 1,
        elementHeight = 1,
        elementSpacing = 0,
        lineSpacing = 0,
    }
    local ok, err = pcall(container.AddAuraGroup, container, key, filter, {
        maxFrameCount = maxCount,
        initializeFrame = function(button) initButton(button, list, auraPrefix) end,
        candidateFilters = {},
        layout = layout,
    })
    if not ok then buildError = 'AddAuraGroup(' .. key .. '): ' .. tostring(err) end
    return ok
end

-- 12.1 AuraContainer owns AuraButton anchoring.  Merely anchoring the
-- container frame is NOT enough; without an explicit flow origin/growth
-- direction Blizzard may choose a different starting slot as the aura count
-- changes.  That was the reason timers moved between different targets.
local function configureFlow(container)
    local anchorFn = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    local growthFn = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    local FD = AnchorUtil and AnchorUtil.FlowDirection

    local anchorOK = false
    local growthOK = false
    if anchorFn then
        anchorOK = pcall(anchorFn, container, 'TOPLEFT')
        if not anchorOK then
            anchorOK = pcall(anchorFn, container, 'BOTTOMLEFT')
        end
    end
    if growthFn and FD then
        if FD.Right and FD.Down then
            growthOK = pcall(growthFn, container, FD.Right, FD.Down)
        end
        if not growthOK and FD.Right and FD.Up then
            growthOK = pcall(growthFn, container, FD.Right, FD.Up)
        end
    end
    return anchorOK, growthOK
end

local function positionRows()
    if not root or not helpfulContainer or not harmfulContainer then return end
    helpfulContainer:ClearAllPoints()
    harmfulContainer:ClearAllPoints()
    local rowStep = ICON
    helpfulContainer:SetPoint('TOPLEFT', root, 'TOPLEFT', 0, 0)
    harmfulContainer:SetPoint('TOPLEFT', root, 'TOPLEFT', 0, -rowStep)
end

-- Ellesmere UI owns different Target AuraKit buttons, so Blizzard TargetFrame
-- holders are not the visible timers while Ellesmere Unit Frames are active.
-- Drive Ellesmere's live profile and ask its own AuraKit registry to restyle.
local euiOriginal
local function getEllesmereTarget()
    local EUI = _G.EllesmereUI
    local ns = EUI and EUI._ModuleNS and EUI._ModuleNS['EllesmereUIUnitFrames']
    if not ns then return nil, nil end
    local profile
    if ns.db and type(ns.db.profile) == 'table' then
        profile = ns.db.profile
    elseif ns.UF_GetProfile then
        local ok, value = pcall(ns.UF_GetProfile)
        if ok and type(value) == 'table' then profile = value end
    end
    if type(profile) ~= 'table' or type(profile.target) ~= 'table' then return nil, nil end
    return ns, profile.target
end

local euiApplied = { buffIcon=nil, debuffIcon=nil }

local function refreshEllesmereTargetAuras(ns, restyle)
    -- RestyleSoon updates existing AuraKit buttons, but Ellesmere keeps some
    -- target aura duration visibility/geometry on the container configuration.
    -- Apply style passes both before and after its own aura-container refresh.
    -- Never rebuild the whole unit frame here.
    if restyle then pcall(restyle) end
    if InCombatLockdown and InCombatLockdown() then
        if C_Timer and C_Timer.After then C_Timer.After(.35,function() if not InCombatLockdown() then refreshEllesmereTargetAuras(ns,restyle) end end) end
        return
    end
    if ns then
        local fn=ns.UF_ReloadAuraContainers or ns.ReloadAuraContainers or ns.UF_RefreshAuraContainers
        if type(fn)=='function' then pcall(fn) end
    end
    if C_Timer and C_Timer.After and restyle then
        C_Timer.After(0,restyle); C_Timer.After(.10,restyle); C_Timer.After(.35,restyle)
    end
end
local function applyEllesmereBridge()
    local ns, target = getEllesmereTarget()
    if not target then return false end
    if not euiOriginal then
        euiOriginal = {
            buffShowCooldownText=target.buffShowCooldownText, debuffShowCooldownText=target.debuffShowCooldownText,
            buffCooldownTextSize=target.buffCooldownTextSize, debuffCooldownTextSize=target.debuffCooldownTextSize,
            buffSize=target.buffSize, debuffSize=target.debuffSize,
            showBuffs=target.showBuffs, debuffAnchor=target.debuffAnchor,
        }
    end

    local at=Addon and Addon.ForeverAuraText
    -- IMPORTANT: Target BUFF TEXT / DEBUFF TEXT live in the normal GODMODE
    -- target aura themes.  The old bridge accidentally read the separate
    -- Target Frame panel values, so the +/- quick controls could never drive
    -- Ellesmere's visible AuraKit countdowns.
    local profile=Addon.db and Addon.db.profile
    local tf=profile and profile.godmodeModuleText and profile.godmodeModuleText.targetFrame
    local buffText=tonumber(tf and tf.buffSize) or (at and at.GetScopedTextSize and at:GetScopedTextSize('TARGET','BUFF')) or 12
    local debuffText=tonumber(tf and tf.debuffSize) or (at and at.GetScopedTextSize and at:GetScopedTextSize('TARGET','DEBUFF')) or 12
    local buffIcon=(at and at.GetScopedIconSize and at:GetScopedIconSize('TARGET','BUFF')) or tonumber(target.buffSize) or 32
    local debuffIcon=(at and at.GetScopedIconSize and at:GetScopedIconSize('TARGET','DEBUFF')) or tonumber(target.debuffSize) or 32

    local iconDirty=false
    -- The same independent TARGET Buff/Debuff switches must control Ellesmere's
    -- live target AuraKit row too.  Ellesmere gates buffs with showBuffs and
    -- debuffs with debuffAnchor='none'. Preserve its chosen debuff anchor.
    local targetBuffOn = frameAuraEnabled('BUFF')
    local targetDebuffOn = frameAuraEnabled('DEBUFF')
    target.showBuffs = targetBuffOn and true or false
    if targetDebuffOn then
        if target.debuffAnchor=='none' then target.debuffAnchor=(euiOriginal.debuffAnchor and euiOriginal.debuffAnchor~='none') and euiOriginal.debuffAnchor or 'bottomleft' end
    else
        if target.debuffAnchor and target.debuffAnchor~='none' then euiOriginal.debuffAnchor=target.debuffAnchor end
        target.debuffAnchor='none'
    end
    -- YOUR BUFFS / DEBUFFS is explicitly linked to the selected Target Frame.
    -- Do not let stale per-scope ownership flags undo the live linked values.
    local buffTextOn = frameCountdownTextEnabled('BUFF')
    local debuffTextOn = frameCountdownTextEnabled('DEBUFF')
    target.buffShowCooldownText=buffTextOn and true or false
    target.buffCooldownTextSize=buffText
    if target.buffSize~=buffIcon then target.buffSize=buffIcon; iconDirty=true end
    euiApplied.buffIcon=buffIcon
    target.debuffShowCooldownText=debuffTextOn and true or false
    target.debuffCooldownTextSize=debuffText
    if target.debuffSize~=debuffIcon then target.debuffSize=debuffIcon; iconDirty=true end
    euiApplied.debuffIcon=debuffIcon

    -- Never reload/rebuild Ellesmere's unit frame from a GODMODE size click.
    -- The old bridge called UF_ReloadAuraContainers and made the whole frame jump.
    -- We update AuraKit's live style below; its RestyleSoon path resizes/re-fonts
    -- the existing secure aura buttons without reconstructing Player/Target.

    -- Live text/icon typography bridge. Ellesmere owns the secure AuraKit
    -- buttons; GODMODE owns their presentation while the scope is released to us.
    local EUI=_G.EllesmereUI
    local AK=EUI and EUI.AuraKit
    local LSM=LibStub and LibStub('LibSharedMedia-3.0',true)
    local themes=profile and profile.themes
    local function godFont(kind)
        local th=themes and themes['auras']
        if not th then th=themes and themes.default end
        return (th and th.font and LSM and LSM:Fetch('font',th.font)) or STANDARD_TEXT_FONT
    end
    local function restyle()
        if not (AK and type(AK.styles)=='table') then return end
        for key,st in pairs(AK.styles) do
            if type(key)=='string' and type(st)=='table' then
                -- Ellesmere has changed/derived AuraKit style-key names across
                -- Forever builds. Do not require the old exact uf:target:* prefix:
                -- drive every TARGET helpful/harmful style that actually exists.
                local lk=key:lower()
                local isTarget=lk:find('target',1,true)~=nil
                local isBuff=isTarget and (lk:find('helpful',1,true)~=nil or lk:find('buff',1,true)~=nil)
                local isDebuff=isTarget and (lk:find('harmful',1,true)~=nil or lk:find('debuff',1,true)~=nil)
                if isBuff and not isDebuff then
                    local pnt=frameCountdownTextAnchor('BUFF'); local tx,ty=0,0; if at and at.GetFrameCountdownTextOffset then tx,ty=at:GetFrameCountdownTextOffset('BUFF') end
                    st.cdTextSize=buffTextOn and buffText or 0; st.showCooldownText=buffTextOn; st.durationShow=buffTextOn; st.showDuration=buffTextOn; st.durationTextSize=buffText
                    st.cdTextPoint=pnt; st.cdTextAnchor=pnt; st.cdTextX=tx; st.cdTextY=ty; st.fontPath=godFont('BUFF')
                    st.width=buffIcon; st.height=buffIcon
                    if AK.RestyleSoon then pcall(AK.RestyleSoon,key) end
                elseif isDebuff then
                    local pnt=frameCountdownTextAnchor('DEBUFF'); local tx,ty=0,0; if at and at.GetFrameCountdownTextOffset then tx,ty=at:GetFrameCountdownTextOffset('DEBUFF') end
                    st.cdTextSize=debuffTextOn and debuffText or 0; st.showCooldownText=debuffTextOn; st.durationShow=debuffTextOn; st.showDuration=debuffTextOn; st.durationTextSize=debuffText
                    st.cdTextPoint=pnt; st.cdTextAnchor=pnt; st.cdTextX=tx; st.cdTextY=ty; st.fontPath=godFont('DEBUFF')
                    st.width=debuffIcon; st.height=debuffIcon
                    if AK.RestyleSoon then pcall(AK.RestyleSoon,key) end
                end
            end
        end
    end
    -- Apply to every currently registered target AuraKit style, then ask
    -- Ellesmere to refresh only its aura containers. This is required for
    -- Target Text OFF and for derived/personal buff styles created after the
    -- first RestyleSoon pass. It deliberately avoids a full frame rebuild.
    refreshEllesmereTargetAuras(ns,restyle)
    if Addon.SyncEllesmereAuraFonts then pcall(Addon.SyncEllesmereAuraFonts) end
    return true
end

local function applyTheme()
    resolveAllRealButtons()
    local euiActive = applyEllesmereBridge()
    for _, rec in ipairs(helpfulTexts) do
        styleText(rec.text,'BUFF')
        if rec.holder and rec.realButton then rec.holder:ClearAllPoints(); local p=frameCountdownTextAnchor('BUFF'); local at=Addon.ForeverAuraText; local x,y=0,0; if at and at.GetFrameCountdownTextOffset then x,y=at:GetFrameCountdownTextOffset('BUFF') end; rec.holder:SetPoint(p,rec.realButton,p,x or 0,y or 0) end
        if rec.realButton and rec.realButton.IsShown then
            rec.holder:SetShown(frameAuraEnabled('BUFF') and frameCountdownTextEnabled('BUFF') and (not euiActive) and (not compatBuffs) and rec.realButton:IsShown())
        end
    end
    for _, rec in ipairs(harmfulTexts) do
        styleText(rec.text,'DEBUFF')
        if rec.holder and rec.realButton then rec.holder:ClearAllPoints(); local p=frameCountdownTextAnchor('DEBUFF'); local at=Addon.ForeverAuraText; local x,y=0,0; if at and at.GetFrameCountdownTextOffset then x,y=at:GetFrameCountdownTextOffset('DEBUFF') end; rec.holder:SetPoint(p,rec.realButton,p,x or 0,y or 0) end
        if rec.realButton and rec.realButton.IsShown then
            rec.holder:SetShown(frameAuraEnabled('DEBUFF') and frameCountdownTextEnabled('DEBUFF') and (not euiActive) and (not compatDebuffs) and rec.realButton:IsShown())
        end
    end
end

local function directTargetButtons(prefix, kind, maxCount)
    local enabled = frameCountdownTextEnabled(kind)
    local at = Addon and Addon.ForeverAuraText
    local point = frameCountdownTextAnchor(kind)
    local x,y=0,0
    if at and at.GetFrameCountdownTextOffset then x,y=at:GetFrameCountdownTextOffset(kind) end
    local theme=getTheme()
    local LSM=LibStub and LibStub('LibSharedMedia-3.0',true)
    local font=STANDARD_TEXT_FONT
    if theme and theme.font and LSM then font=LSM:Fetch('font',theme.font) or font end
    local size=(at and at.GetScopedTextSize and at:GetScopedTextSize('TARGET',kind)) or (theme and tonumber(theme.fontSize)) or 12
    local flags=(theme and theme.fontFlags~=nil) and theme.fontFlags or 'OUTLINE'
    for i=1,maxCount do
        local b=_G['TargetFrame'..prefix..i]
        if b then
            local fs=b.Duration or b.duration or b.TimerText or b.TimeText or b.timeText
            if fs and fs.SetFont then
                pcall(fs.SetFont,fs,font,size,flags)
                pcall(fs.SetShown,fs,enabled and b:IsShown())
                if enabled then
                    pcall(fs.ClearAllPoints,fs)
                    pcall(fs.SetPoint,fs,point,b,point,x or 0,y or 0)
                    -- Blizzard's native Duration text defaults to bottom justification.
                    -- Re-anchor AND set vertical justification so CENTER is truly centered.
                    pcall(fs.SetJustifyH,fs,'CENTER')
                    pcall(fs.SetJustifyV,fs,point)
                end
            end
            local cd=b.Cooldown or b.cooldown or b.CooldownFrame or b.cooldownFrame
            if cd and cd.SetHideCountdownNumbers then
                -- Blizzard's own countdown must stay hidden: GODMODE uses the
                -- button's existing Duration FontString. No custom AuraContainer.
                pcall(cd.SetHideCountdownNumbers,cd,true)
                cd.noCooldownCount=true
            end
        end
    end
end

local function applyDirectTargetText()
    -- Ellesmere owns its own target AuraKit; use its style bridge there.
    applyEllesmereBridge()
    directTargetButtons('Buff','BUFF',MAX_HELPFUL)
    directTargetButtons('Debuff','DEBUFF',MAX_HARMFUL)
end

local function build()
    -- Forever safety: NEVER create/add groups to Blizzard AuraContainer here.
    -- TargetFrame already owns the aura buttons. We only style their existing
    -- duration FontStrings after Blizzard has created them.
    built=true
    buildError=nil
    applyDirectTargetText()
    return true
end

Addon.ForeverTargetAuraTimers = Addon.ForeverTargetAuraTimers or {}
Addon.ForeverTargetAuraTimers.ApplyTheme = applyTheme
Addon.ForeverTargetAuraTimers.Build = build
-- Live control bridge: the Buffs/Debuffs controls must update the renderer that
-- is ACTUALLY loaded on Forever. Rebuild secure duration sources only when icon
-- geometry changes are requested; typography reapplies immediately.
local liveApplyToken = 0
Addon.ForeverTargetAuraTimers.RequestApply = function()
    liveApplyToken = liveApplyToken + 1
    local token = liveApplyToken
    applyDirectTargetText()
    C_Timer.After(0, function()
        if token ~= liveApplyToken then return end
        applyDirectTargetText()
    end)
end
Addon.ForeverTargetAuraTimers.ApplyVisibility = function()
    applyDirectTargetText()
end

function Addon.ForeverTargetAuraTimers.SetCompatibilityScopes(buffExternal, debuffExternal)
    compatBuffs = buffExternal and true or false
    compatDebuffs = debuffExternal and true or false
    applyDirectTargetText()
end


local oldRefresh
local function installRefreshHook()
    if oldRefresh or not Addon or not Addon.Refresh then return end
    oldRefresh = Addon.Refresh
    Addon.Refresh = function(self, ...)
        local ret = oldRefresh(self, ...)
        -- Typography only; no secure frame movement or parent access.
        C_Timer.After(0, applyDirectTargetText)
        return ret
    end
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_TARGET_CHANGED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function()
    if not built then build() end
    if built then
        C_Timer.After(0, applyDirectTargetText)
        C_Timer.After(.05, applyDirectTargetText)
    end
    installRefreshHook()
end)

SLASH_OGMTARGETDEBUG1 = '/ogmtargetdebug'
SlashCmdList.OGMTARGETDEBUG = function()
    if not built then build() end
    print(string.format('|cffffd200OmniCC GODMODE Target Debug:|r secureContainer=%s helpfulTexts=%d harmfulTexts=%d error=%s',
        built and 'YES' or 'NO', #helpfulTexts, #harmfulTexts, tostring(buildError or 'none')))
end
