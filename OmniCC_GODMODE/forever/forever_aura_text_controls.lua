local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

-- Forever-only controls for Blizzard unit aura icons and their duration text.
-- This module intentionally works from Blizzard's rendered aura frames instead
-- of reading aura spell data, which keeps it compatible with Forever secret values.
local AuraText = {}
Addon.ForeverAuraText = AuraText

local DEFAULT_TEXT_BUFF, DEFAULT_TEXT_DEBUFF = 10, 10
-- SELF/TARGET are intentionally compact unit-frame auras. These values NEVER
-- control Blizzard BuffFrame/DebuffFrame beside the minimap or action bars.
local DEFAULT_ICON_BUFF, DEFAULT_ICON_DEBUFF = 18, 18
local MIN_TEXT, MAX_TEXT = 7, 18
local MIN_ICON, MAX_ICON = 12, 26
local DEFAULT_MINIMAP_TEXT_BUFF, DEFAULT_MINIMAP_TEXT_DEBUFF = 10, 10
local DEFAULT_MINIMAP_ICON_BUFF, DEFAULT_MINIMAP_ICON_DEBUFF = 30, 30
local MIN_MINIMAP_ICON, MAX_MINIMAP_ICON = 20, 50

local registered = setmetatable({}, {__mode='k'}) -- aura button -> BUFF/DEBUFF
local cooldownKind = setmetatable({}, {__mode='k'})
local nativeWidth = setmetatable({}, {__mode='k'})
local nativeMinimap = setmetatable({}, {__mode='k'}) -- exact Blizzard geometry/font captured before GODMODE changes it
local hooked = false
local nativeMinimapFrameScale = setmetatable({}, {__mode="k"})
local minimapLayoutBusy = false

local function clamp(v, lo, hi, default)
    v = tonumber(v) or default
    if v < lo then return lo end
    if v > hi then return hi end
    return math.floor(v + 0.5)
end

local TARGET_DB_NAME = "OmniCC_GODMODE_ForeverAuraQuickDB"

local function targetSettings()
    local t = rawget(_G, TARGET_DB_NAME)
    if type(t) ~= 'table' then
        t = {}
        rawset(_G, TARGET_DB_NAME, t)
    end
    -- v1.2.5-P: text is no longer stored here.  Target/nameplate text lives
    -- only in the real AceDB themes so the full Themes panel and Quick Controls
    -- can never fight each other. Keep this DB only for per-kind icon sizes.
    t.buffIcon = clamp(t.buffIcon, MIN_ICON, MAX_ICON, DEFAULT_ICON_BUFF)
    t.debuffIcon = clamp(t.debuffIcon, MIN_ICON, MAX_ICON, DEFAULT_ICON_DEBUFF)
    t.textOverride = nil
    t.forceText = nil
    t.buff = nil
    t.debuff = nil
    t.initialized = true
    return t
end

local function targetThemeID(kind)
    return 'auras'
end

local function getTargetTheme(kind)
    local profile = Addon.db and Addon.db.profile
    local themes = profile and profile.themes
    return themes and themes[(profile.godmodeAutoFitEnabled and 'godmode_autofit') or targetThemeID(kind)] or nil
end

local function scopedSettings(scope)
    -- Target/nameplate quick overrides were removed.  Full Themes -> Nameplates
    -- is now the single source of truth for target/nameplate cooldown text.
    if not Addon.db or not Addon.db.profile then return nil end
    local p = Addon.db.profile
    p.godmodeAuraText = p.godmodeAuraText or {}
    local root = p.godmodeAuraText

    if type(root.player) ~= 'table' then
        root.player = {
            buff = root.buff or root.buffText,
            debuff = root.debuff or root.debuffText,
            buffIcon = root.buffIcon,
            debuffIcon = root.debuffIcon,
        }
    end

    local s = root.player
    s.buff = clamp(s.buff or s.buffText, MIN_TEXT, MAX_TEXT, DEFAULT_TEXT_BUFF)
    s.debuff = clamp(s.debuff or s.debuffText, MIN_TEXT, MAX_TEXT, DEFAULT_TEXT_DEBUFF)
    -- Frame aura visibility is user-configurable, but ON by default.
    -- Separate visibility switches for SELF and TARGET, all ON by default.
    if s.selfFrameBuffsEnabled == nil then s.selfFrameBuffsEnabled = (s.frameBuffsEnabled ~= false) end
    if s.selfFrameDebuffsEnabled == nil then s.selfFrameDebuffsEnabled = (s.frameDebuffsEnabled ~= false) end
    if s.targetFrameBuffsEnabled == nil then s.targetFrameBuffsEnabled = (s.frameBuffsEnabled ~= false) end
    if s.targetFrameDebuffsEnabled == nil then s.targetFrameDebuffsEnabled = (s.frameDebuffsEnabled ~= false) end
    s.buffIcon = clamp(s.buffIcon, MIN_ICON, MAX_ICON, DEFAULT_ICON_BUFF)
    s.debuffIcon = clamp(s.debuffIcon, MIN_ICON, MAX_ICON, DEFAULT_ICON_DEBUFF)
    if s.selfFrameX == nil then s.selfFrameX = 0 end
    if s.selfFrameY == nil then s.selfFrameY = 0 end
    if s.inheritBlizzardDebuffBorder == nil then s.inheritBlizzardDebuffBorder = true end
    -- SELF + TARGET countdown visibility. Preserve the older self-debuff choice
    -- when upgrading, but keep BUFF and DEBUFF independently configurable now.
    if s.frameBuffCountdownTextEnabled == nil then s.frameBuffCountdownTextEnabled = true end
    -- Countdown text anchor shared by SELF + TARGET for each aura kind.
    -- BOTTOM matches the approved SELF-frame presentation.
    if s.frameBuffCountdownTextAnchor == nil then s.frameBuffCountdownTextAnchor = 'BOTTOM' end
    if s.frameDebuffCountdownTextAnchor == nil then s.frameDebuffCountdownTextAnchor = 'BOTTOM' end
    if s.frameBuffCountdownTextX == nil then s.frameBuffCountdownTextX = 0 end
    if s.frameBuffCountdownTextY == nil then s.frameBuffCountdownTextY = 0 end
    if s.frameDebuffCountdownTextX == nil then s.frameDebuffCountdownTextX = 0 end
    if s.frameDebuffCountdownTextY == nil then s.frameDebuffCountdownTextY = 0 end
    if s.frameDebuffCountdownTextEnabled == nil then
        if s.selfDebuffCountdownTextEnabled ~= nil then
            s.frameDebuffCountdownTextEnabled = s.selfDebuffCountdownTextEnabled ~= false
        else
            s.frameDebuffCountdownTextEnabled = true
        end
    end
    s.selfDebuffCountdownTextEnabled = s.frameDebuffCountdownTextEnabled ~= false
    -- Blizzard personal auras beside the minimap have their OWN controller.
    -- IMPORTANT: nil means NATIVE BLIZZARD. Never manufacture/save defaults here.
    -- This preserves existing user values while new users stay byte-for-byte at
    -- Blizzard sizing until they deliberately touch the minimap controls.
    if type(root.minimap) ~= 'table' then root.minimap = {} end
    local m = root.minimap
    if m.buff ~= nil then m.buff = clamp(m.buff, MIN_TEXT, MAX_TEXT, DEFAULT_MINIMAP_TEXT_BUFF) end
    if m.debuff ~= nil then m.debuff = clamp(m.debuff, MIN_TEXT, MAX_TEXT, DEFAULT_MINIMAP_TEXT_DEBUFF) end
    if m.buffIcon ~= nil then m.buffIcon = clamp(m.buffIcon, MIN_MINIMAP_ICON, MAX_MINIMAP_ICON, DEFAULT_MINIMAP_ICON_BUFF) end
    if m.debuffIcon ~= nil then m.debuffIcon = clamp(m.debuffIcon, MIN_MINIMAP_ICON, MAX_MINIMAP_ICON, DEFAULT_MINIMAP_ICON_DEBUFF) end
    return s
end

local function minimapSettings()
    scopedSettings('PLAYER')
    local p=Addon.db and Addon.db.profile
    local root=p and p.godmodeAuraText
    return root and root.minimap or nil
end

local function settings() return scopedSettings('PLAYER') end

local function setFontSize(fs, size)
    if not fs or not fs.GetFont or not fs.SetFont then return false end
    local ok, path, _, flags = pcall(fs.GetFont, fs)
    if not ok then return false end
    path = path or STANDARD_TEXT_FONT
    local success = pcall(fs.SetFont, fs, path, size, flags)
    if not success then success = pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, flags) end
    if success then
        pcall(fs.SetScale, fs, 1)
        pcall(fs.SetAlpha, fs, 1)
    end
    return success
end

local sourceKind = setmetatable({}, {__mode='k'})
local reapplyOnce

-- Minimap personal auras: use Blizzard's ACTUAL visible Duration FontString.
-- AuraButton:SetDurationText supports rebinding that exact FontString to GODMODE's
-- secure formatter/color curve.  Do not create a second FontString and do not hide
-- Blizzard's Duration: doing so removes the only text object Blizzard reliably
-- drives on these buttons.
-- Cache Blizzard's original duration appearance before the optional GODMODE bridge.
-- Never replace its text or duration provider: Blizzard owns aura lifetimes.
local minimapOriginalFonts = setmetatable({}, {__mode='k'})
local function minimapThemeEnabled()
    local profile=Addon.db and Addon.db.profile
    local surfaces=profile and profile.godmodeCooldownSurfaces
    return not surfaces or surfaces.minimapBuffs ~= false
end
local function restoreMinimapDuration(fs)
    local original=minimapOriginalFonts[fs]
    if not original then return end
    if original.font then pcall(fs.SetFont,fs,original.font,original.size,original.flags) end
    if original.r then pcall(fs.SetVertexColor,fs,original.r,original.g,original.b,original.a) end
    if original.shadowR and fs.SetShadowColor then
        pcall(fs.SetShadowColor,fs,original.shadowR,original.shadowG,original.shadowB,original.shadowA)
    end
    if original.shadowX and fs.SetShadowOffset then
        pcall(fs.SetShadowOffset,fs,original.shadowX,original.shadowY)
    end
end
local function styleMinimapDuration(fs, textSize)
    local profile=Addon.db and Addon.db.profile
    local theme=profile and profile.themes and profile.themes.auras
    if not theme then return end
    if not minimapOriginalFonts[fs] then
        local original={}
        local ok,font,size,flags=pcall(fs.GetFont,fs)
        if ok and type(size)=='number' then original.font,original.size,original.flags=font,size,flags end
        if fs.GetTextColor then
            local good,r,g,b,a=pcall(fs.GetTextColor,fs)
            if good and type(r)=='number' then original.r,original.g,original.b,original.a=r,g,b,a end
        end
        if fs.GetShadowColor then
            local good,r,g,b,a=pcall(fs.GetShadowColor,fs)
            if good and type(r)=='number' then original.shadowR,original.shadowG,original.shadowB,original.shadowA=r,g,b,a end
        end
        if fs.GetShadowOffset then
            local good,x,y=pcall(fs.GetShadowOffset,fs)
            if good and type(x)=='number' then original.shadowX,original.shadowY=x,y end
        end
        minimapOriginalFonts[fs]=original
    end
    local original=minimapOriginalFonts[fs]
    local font=theme.font or theme.fontFace or (original and original.font) or STANDARD_TEXT_FONT
    local size=tonumber(textSize) or tonumber(theme.fontSize) or (original and original.size) or 10
    if size < 1 or size > 96 then size=10 end
    pcall(fs.SetFont,fs,font,size,theme.fontFlags or (original and original.flags) or '')
    -- Native Blizzard duration values are protected on Midnight. Do not parse
    -- GetText() or perform secret-number comparisons to choose a color tier.
    -- Apply the configured default aura-theme color without changing text.
    if theme.defaultTextColor and Addon.HexToRGBA then
        local ok,r,g,b,a=pcall(Addon.HexToRGBA,theme.defaultTextColor)
        if ok and type(r)=='number' then pcall(fs.SetVertexColor,fs,r,g,b,a or 1) end
    end
    if theme.shadowColor and Addon.HexToRGBA then
        local ok,r,g,b,a=pcall(Addon.HexToRGBA,theme.shadowColor)
        if ok and type(r)=='number' then
            if fs.SetShadowColor then pcall(fs.SetShadowColor,fs,r,g,b,a or 1) end
            if fs.SetShadowOffset then pcall(fs.SetShadowOffset,fs,tonumber(theme.shadowX) or 0,tonumber(theme.shadowY) or 0) end
        end
    end
end

-- Blizzard AuraButton's duration binding owns its color every frame on newer clients.
-- A one-time FontString:SetTextColor is overwritten by that binding. Supply a
-- constant color curve through the supported aura API instead of reading secret
-- duration values or fighting the native OnUpdate loop.
local isBlizzardMinimapAura -- forward declaration: used by bindMinimapDurationColor
local minimapBoundColors = setmetatable({}, {__mode='k'})
-- Use the SAME threshold colors as the aura theme engine.  The old bridge
-- only used defaultTextColor, which is commonly yellow while the configured
-- duration ranges (including minutes) are green.  Never read secure durations.
local function bindMinimapDurationColor(button, fs)
    if not isBlizzardMinimapAura(button) or not fs or not button.SetDurationText or not C_CurveUtil
        or not C_CurveUtil.CreateColorCurve or not CreateColor then return end
    local profile=Addon.db and Addon.db.profile
    local theme=profile and profile.themes and profile.themes.auras
    if not theme or not Addon.HexToRGBA then return end
    local entries={}
    if type(theme.textColors)=='table' then
        for _,entry in ipairs(theme.textColors) do
            local threshold=type(entry)=='table' and tonumber(entry.threshold)
            local color=type(entry)=='table' and entry.color
            if threshold and type(color)=='string' then
                local ok,r,g,b,a=pcall(Addon.HexToRGBA,color)
                if ok and type(r)=='number' then
                    entries[#entries+1]={threshold=threshold,r=r,g=g,b=b,a=a or 1}
                end
            end
        end
    end
    table.sort(entries,function(x,y) return x.threshold<y.threshold end)
    local default=theme.defaultTextColor or 'FFFFFFFF'
    local ok,dr,dg,db,da=pcall(Addon.HexToRGBA,default)
    if not ok or type(dr)~='number' then return end
    local parts={default}
    for _,e in ipairs(entries) do
        parts[#parts+1]=string.format('%s:%s:%s:%s:%s',e.threshold,e.r,e.g,e.b,e.a)
    end
    local key=table.concat(parts,'|')
    if minimapBoundColors[button]==key then return end
    local success=pcall(function()
        local curve=C_CurveUtil.CreateColorCurve()
        if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
            curve:SetType(Enum.LuaCurveType.Step)
        end
        if #entries>0 then
            curve:AddPoint(0,CreateColor(entries[1].r,entries[1].g,entries[1].b,entries[1].a))
            for i=2,#entries do
                local e=entries[i]
                curve:AddPoint(entries[i-1].threshold,CreateColor(e.r,e.g,e.b,e.a))
            end
            curve:AddPoint(entries[#entries].threshold,CreateColor(dr,dg,db,da or 1))
        else
            curve:AddPoint(0,CreateColor(dr,dg,db,da or 1))
        end
        local property=Enum and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration
        if property==nil then property=0 end
        button:SetDurationText(fs,{textColor={curve=curve,property=property}})
    end)
    if success then minimapBoundColors[button]=key end
end

-- Blizzard's legacy BuffFrame duration updater overwrites FontString vertex color
-- on every duration tick. Reapply ONLY to native player BuffFrame/DebuffFrame
-- buttons immediately after that updater; no generic frame or portrait hooks.
local function reapplyNativeMinimapVertex(button)
    if not isBlizzardMinimapAura(button) or not minimapThemeEnabled() then return end
    local fs=button and (button.Duration or button.duration)
    if not fs or not fs.SetVertexColor then return end
    local p=Addon.db and Addon.db.profile
    local theme=p and p.themes and p.themes.auras
    if not theme or not Addon.HexToRGBA then return end
    local hex=theme.defaultTextColor
    if type(theme.textColors)=='table' and #theme.textColors>0 then
        -- Avoid reading potentially protected timeLeft; use the theme's first
        -- configured tier rather than inspecting any protected aura duration.
        local first=theme.textColors[1]
        if type(first)=='table' and type(first.color)=='string' then hex=first.color end
    end
    if type(hex)~='string' then return end
    local ok,r,g,b,a=pcall(Addon.HexToRGBA,hex)
    if ok and type(r)=='number' then pcall(fs.SetVertexColor,fs,r,g,b,a or 1) end
end
if type(hooksecurefunc)=='function' and type(_G.AuraButton_UpdateDuration)=='function' then
    hooksecurefunc('AuraButton_UpdateDuration',function(button)
        reapplyNativeMinimapVertex(button)
    end)
end

-- Strictly isolate the minimap timer bridge to Blizzard's own BuffFrame and
-- DebuffFrame descendants. Never bind GODMODE Player/Target aura rows, TPerl,
-- portrait effects, or any third-party aura button to Blizzard's native API.
isBlizzardMinimapAura = function(button)
    if not button then return false end
    local ok, result = pcall(function()
        local frame = button
        for i=1,12 do
            if not frame then return false end
            if frame == _G.BuffFrame or frame == _G.DebuffFrame then return true end
            frame = frame.GetParent and frame:GetParent() or nil
        end
        local name = button.GetName and button:GetName() or ''
        if type(name)=='string' and
            (name:match('^BuffButton%d+$') or name:match('^DebuffButton%d+$')) then
            return true
        end
        return false
    end)
    return ok and result == true
end

local function minimapThemeText(button, textSize)
    if not isBlizzardMinimapAura(button) then return nil end
    local fs=button.Duration or button.duration or button.TimerText or button.TimeText or button.timeText
    if not fs then return nil end
    if not minimapThemeEnabled() then
        if minimapBoundColors[button] and button.SetDurationText then
            pcall(button.SetDurationText,button,fs,{})
            minimapBoundColors[button]=nil
        end
        restoreMinimapDuration(fs)
        return fs
    end
    styleMinimapDuration(fs,textSize)
    bindMinimapDurationColor(button,fs)

    -- IMPORTANT: Blizzard owns the lifetime/value/visibility of minimap aura
    -- duration text. AuraContainer recycles these buttons. Rebinding or forcing
    -- Show() here can make permanent/state auras (Cat Form, Nightskulker Ring)
    -- inherit a previous timed aura's text. Styling only is safe; Blizzard will
    -- show a timer only when the CURRENT aura actually has one.
    local cd=button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame
    -- Do not alter Blizzard's countdown ownership or visibility.
    return fs
end

-- Appearance-only bridge: leave Blizzard's duration, timer text, and visibility
-- completely under their existing owners. Do not rebind AuraContainer timers.
local function applyAuraSwipe(cooldown)
    if not cooldown then return end
    local profile = Addon.db and Addon.db.profile
    local theme = profile and profile.themes and profile.themes.auras
    if not theme then return end
    local enabled = theme.themeCooldown ~= false
    -- Theme options use the strings "always", "never", "default".
    -- Treating "never" as truthy made Show Swipe/Reverse ignore the menu.
    local function flag(value, fallback)
        if value == "always" then return true end
        if value == "never" then return false end
        if value == nil or value == "default" then return fallback end
        return value ~= false
    end
    if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, enabled and flag(theme.drawSwipe, true)) end
    if cooldown.SetDrawEdge then pcall(cooldown.SetDrawEdge, cooldown, enabled and flag(theme.drawEdge, true)) end
    if cooldown.SetDrawBling then pcall(cooldown.SetDrawBling, cooldown, enabled and flag(theme.drawBling, true)) end
    if cooldown.SetReverse then pcall(cooldown.SetReverse, cooldown, enabled and flag(theme.reverse, false)) end
    if theme.themeSwipeColor and theme.swipeColor and Addon.HexToRGBA and cooldown.SetSwipeColor then
        local ok,r,g,b,a = pcall(Addon.HexToRGBA, theme.swipeColor)
        if ok and r then pcall(cooldown.SetSwipeColor, cooldown, r,g,b,a or 1) end
    end
end


-- Discover the actual native Cooldown region, not only a named .Cooldown field.
-- Bounded to the aura button and its immediate children; never scan nameplates.
local function auraCooldowns(button, visit)
    if not button or not visit then return end
    local seen={}
    local function offer(obj)
        if not obj or seen[obj] then return end
        seen[obj]=true
        local ok, isCD=pcall(function() return obj.IsObjectType and obj:IsObjectType('Cooldown') end)
        if ok and isCD then visit(obj) end
    end
    for _,field in ipairs({'Cooldown','cooldown','CooldownFrame','cooldownFrame','cooldownTimer','CooldownTimer'}) do
        local ok,obj=pcall(function() return button[field] end)
        if ok then offer(obj) end
    end
    if button.GetChildren then
        local ok,children=pcall(function() return {button:GetChildren()} end)
        if ok then
            for i=1,math.min(#children,16) do
                local child=children[i]
                offer(child)
                if child and child.GetChildren then
                    local ok2,grand=pcall(function() return {child:GetChildren()} end)
                    if ok2 then for j=1,math.min(#grand,8) do offer(grand[j]) end end
                end
            end
        end
    end
end

function AuraText:ApplyNativeAuraSwipe(button)
    auraCooldowns(button, applyAuraSwipe)
end

local function registerButton(button, kind, source)
    -- Compatibility hard guard: if an external addon owns Nameplates,
    -- GODMODE must not attach countdown text to that addon's aura frames.
    if Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates') then
        local n=''
        pcall(function() n=(button.GetName and button:GetName()) or '' end)
        local parent
        pcall(function() parent=button:GetParent() end)
        local pn=''
        pcall(function() pn=(parent and parent.GetName and parent:GetName()) or '' end)
        if n:find('Threat',1,true) or n:find('TidyPlate',1,true) or pn:find('Threat',1,true) or pn:find('TidyPlate',1,true) then
            return
        end
    end
    if not button then return end
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    registered[button] = kind
    sourceKind[button] = source or sourceKind[button]
    local cd = button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame
    if cd then cooldownKind[cd] = kind end
    auraCooldowns(button, function(native) cooldownKind[native]=kind end)
end

local function scanPersonal()
    -- Bounded discovery of Blizzard's personal aura buttons only. Never bind
    -- timers, create FontStrings, or traverse nameplates. Recycled buttons are
    -- styled only while they belong to the visible personal aura container.
    local function collect(owner, kind)
        if not owner then return end
        local function add(button)
            if not button or (button.IsForbidden and button:IsForbidden()) then return end
            if button.IsObjectType and not button:IsObjectType('Button') then return end
            registerButton(button, kind, 'PLAYER')
        end
        local function pool(container)
            if not container then return end
            local pools = {container.auraPool, container.auraButtonPool, container.buttonPool,
                           container.buffPool, container.debuffPool}
            for _, p in pairs(pools) do
                if p and p.EnumerateActive then
                    for button in p:EnumerateActive() do add(button) end
                end
            end
            if container.GetChildren then
                for _, child in ipairs({container:GetChildren()}) do
                    if child and (child.Duration or child.Icon or child.icon) then add(child) end
                end
            end
        end
        pool(owner)
        pool(owner.AuraContainer)
        pool(owner.auraContainer)
        pool(owner.auraFrame)
    end
    collect(_G.BuffFrame, 'BUFF')
    collect(_G.DebuffFrame, 'DEBUFF')
    -- Older client layouts expose individually named buttons.
    for i=1,40 do
        local buff=_G['BuffButton'..i]
        if buff then registerButton(buff,'BUFF','PLAYER') end
        local debuff=_G['DebuffButton'..i]
        if debuff then registerButton(debuff,'DEBUFF','PLAYER') end
    end
end

-- TARGET/FOCUS auras in Blizzard's live unit frame are NOT auraPools.
-- They are concrete named buttons created by TargetFrame_UpdateAuras():
--   TargetFrameBuff1..32 / TargetFrameDebuff1..16
--   FocusFrameBuff1..32  / FocusFrameDebuff1..16
-- Register those exact visible buttons so the quick controls touch the same
-- frames the player is looking at on the target unit frame.
local function scanNamedUnitAuras(prefix, source)
    local found = 0
    for i = 1, 32 do
        local b = _G[prefix .. 'Buff' .. i]
        if b then
            registerButton(b, 'BUFF', source)
            found = found + 1
        end
    end
    for i = 1, 16 do
        local b = _G[prefix .. 'Debuff' .. i]
        if b then
            registerButton(b, 'DEBUFF', source)
            found = found + 1
        end
    end
    return found
end

function AuraText:ScanAuraFrames()
    -- Quick "YOUR" controls intentionally touch only the player's Blizzard
    -- BuffFrame/DebuffFrame. TARGET quick controls are for GODMODE/nameplate
    -- aura rows and are handled by the rule/theme engine, not TargetFrame.
    scanPersonal()
    -- Target/Focus native buttons are deliberately NOT registered here on
    -- Forever. They can be forbidden objects and are not owned by this module.
    self._lastNamedTargetFound = 0
    self._lastNamedFocusFound = 0
end

-- MINIMAP GEOMETRY -----------------------------------------------------------
-- Blizzard Edit Mode does NOT resize every BuffFrame/DebuffFrame button to an
-- arbitrary width. It keeps the native 30x40/60x30 aura cells and changes
-- AuraContainer.iconScale, then runs the frame's own UpdateGridLayout(). That
-- native grid knows orientation, wrap direction, icon stride and Icon Padding,
-- so scaled icons can never be laid out using stale 30px spacing.
--
-- Previous GODMODE builds used button:SetSize(requested, requested). The icon
-- grew, but Blizzard's grid still positioned neighbours using its native cell
-- geometry, which is exactly how overlap could happen. From here on GODMODE
-- drives the SAME property/path as Blizzard Edit Mode and never writes PLAYER
-- aura button geometry directly.
local MINIMAP_NATIVE_ICON_SIZE = 30

local function minimapFrame(kind)
    if kind == 'DEBUFF' then return _G.DebuffFrame end
    return _G.BuffFrame
end

local function readBlizzardMinimapIconSize(kind)
    local frame=minimapFrame(kind)
    if not frame then return DEFAULT_MINIMAP_ICON_BUFF end

    -- First choice: the actual saved Edit Mode setting. This is authoritative
    -- even after GODMODE has temporarily overridden AuraContainer.iconScale.
    local enum=Enum and Enum.EditModeAuraFrameSetting and Enum.EditModeAuraFrameSetting.IconSize
    if enum and frame.GetSettingValue then
        local ok,v=pcall(frame.GetSettingValue,frame,enum)
        if ok and type(v)=='number' and v>0 then
            return MINIMAP_NATIVE_ICON_SIZE*(v/100)
        end
    end

    -- Fallback for layouts/clients where GetSettingValue is not available yet.
    -- Use the last scale captured from Blizzard BEFORE a GODMODE override rather
    -- than reading our own current override back as if it were Blizzard's value.
    local captured=nativeMinimapFrameScale[frame]
    if type(captured)=='number' and captured>0 then
        return MINIMAP_NATIVE_ICON_SIZE*captured
    end
    local container=frame.AuraContainer or frame.auraContainer
    if container and type(container.iconScale)=='number' and container.iconScale>0 then
        return MINIMAP_NATIVE_ICON_SIZE*container.iconScale
    end
    return DEFAULT_MINIMAP_ICON_BUFF
end

local function requestedMinimapIconSize(kind)
    local m=minimapSettings()
    if not m then return nil end
    return kind=='DEBUFF' and m.debuffIcon or m.buffIcon
end

-- Edit Mode owns protected Blizzard aura layout. Do not write iconScale or
-- force UpdateGridLayout while its systems are being edited.
local function minimapEditModeActive()
    local manager = _G.EditModeManagerFrame
    if not manager then return false end
    local ok, active = pcall(function()
        if manager.IsEditModeActive then return manager:IsEditModeActive() end
        return manager.IsShown and manager:IsShown()
    end)
    return ok and active == true
end

local minimapNativeContainerScale = setmetatable({}, {__mode='k'})
local function applyMinimapNativeLayout(kind, force)
    if InCombatLockdown and InCombatLockdown() then return false end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then return false end
    local frame = minimapFrame(kind)
    if not frame then return false end
    local container = frame.AuraContainer or frame.auraContainer
    if not container or not container.SetScale or not container.GetScale then return false end
    if container.IsForbidden and container:IsForbidden() then return false end
    local original = minimapNativeContainerScale[container]
    if not original then
        local ok, scale = pcall(container.GetScale, container)
        if not ok or type(scale)~='number' or scale<=0 then return false end
        original=scale
        minimapNativeContainerScale[container]=original
    end
    local wanted = AuraText:IsMinimapControlEnabled() and requestedMinimapIconSize(kind) or nil
    local native = readBlizzardMinimapIconSize(kind)
    if type(native)~='number' or native<=0 then native=MINIMAP_NATIVE_ICON_SIZE end
    local multiplier = tonumber(wanted) and tonumber(wanted)>0 and (tonumber(wanted)/native) or 1
    local scale=original*multiplier
    if scale<0.25 or scale>4 then return false end
    local ok,current=pcall(container.GetScale,container)
    if ok and type(current)=='number' and math.abs(current-scale)<0.001 then return true end
    return pcall(container.SetScale,container,scale)
end

local function applyAllMinimapNativeLayouts(force)
    applyMinimapNativeLayout('BUFF',force)
    applyMinimapNativeLayout('DEBUFF',force)
end

-- Blizzard personal auras beside the minimap use an independent saved size/text controller.
local function applyButton(button, kind, s)
    if not button or not kind then return false end
    local src = sourceKind[button]
    if src == 'PLAYER' and AuraText.IsMinimapControlEnabled and not AuraText:IsMinimapControlEnabled() then
        -- Minimap Control toggles ICON GEOMETRY only. The independent
        -- Minimap Buff/Debuff Cooldowns checkbox still owns Blizzard's
        -- native Duration font styling. Never touch unit-frame aura rows.
        if isBlizzardMinimapAura(button) then
            minimapThemeText(button, nil)
            return true
        end
        return false
    end
    if src == 'PLAYER' and isBlizzardMinimapAura(button) and not minimapThemeEnabled() then
        minimapThemeText(button,nil)
        return true
    end
    s = s or scopedSettings((src == 'TARGET' or src == 'FOCUS') and 'TARGET' or 'PLAYER')
    if not s then return false end
    if button.IsForbidden and button:IsForbidden() then return false end
    local auraCooldown = button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame
    applyAuraSwipe(auraCooldown)
    auraCooldowns(button, applyAuraSwipe)
    -- GODMODE's dedicated TARGET renderer owns the visible target aura row.
    -- Never let this generic controller revive Blizzard TargetFrame visuals.
    if src == 'TARGET' then return false end

    local textSize = kind == 'DEBUFF' and s.debuff or s.buff
    local iconSize = kind == 'DEBUFF' and s.debuffIcon or s.buffIcon
    if src == 'PLAYER' then
        local m=minimapSettings()
        if m then textSize = kind == 'DEBUFF' and m.debuff or m.buff end
    end

    -- PLAYER BUFF/DEBUFF FRAMES: Blizzard Forever renders its own Duration
    -- FontString under/over the icon. This is the text users see as "54m" etc.
    if button.Duration and textSize ~= nil then
        if src ~= 'PLAYER' then
            setFontSize(button.Duration, textSize)
            pcall(button.Duration.SetAlpha, button.Duration, 1)
        end
        -- Blizzard personal auras beside the minimap are real AuraContainer
        -- duration texts. Size alone used to be applied here, leaving their
        -- color under Blizzard/native control. Bind the visible Duration text
        -- to the unified Buffs & Debuffs theme so the same live threshold-color
        -- curve used by SELF/TARGET also owns minimap BUFF/DEBUFF countdowns.
        if src == 'PLAYER' then
            minimapThemeText(button, textSize)
        end
    end

    -- TARGET/FOCUS FRAMES: Forever renders the timer inside Cooldown. The
    -- generated countdown can be returned by GetCountdownFontString(), but in
    -- some 12.1 layouts the visible region is only exposed through GetRegions().
    local cd = button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame
    if cd then
        applyAuraSwipe(cd)
        cooldownKind[cd] = kind
        if src ~= 'PLAYER' and cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers, cd, false) end
        local seen = {}
        local function styleCooldownText(fs)
            if not fs or seen[fs] then return end
            seen[fs] = true
            -- On Target/Focus, scaling the Blizzard-created FontString is more
            -- stable than replacing its font every aura refresh.
            local src = sourceKind[button]
            if src == 'TARGET' or src == 'FOCUS' then
                -- These are ordinary Blizzard TargetFrame cooldown FontStrings.
                -- Set the requested font size directly and keep scale at 1 so
                -- the result matches the Preview exactly.
                setFontSize(fs, textSize)
                if fs.SetScale then pcall(fs.SetScale, fs, 1) end
                if fs.SetAlpha then pcall(fs.SetAlpha, fs, 1) end
            else
                setFontSize(fs, textSize)
            end
        end
        if cd.GetCountdownFontString then
            local ok, fs = pcall(cd.GetCountdownFontString, cd)
            if ok and fs then styleCooldownText(fs) end
        end
        if cd.GetRegions then
            local ok, regions = pcall(function() return {cd:GetRegions()} end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType then
                        local rok, typ = pcall(region.GetObjectType, region)
                        if rok and typ == 'FontString' then styleCooldownText(region) end
                    end
                end
            end
        end
    end

    -- Player aura layout behaves differently and already worked in testing.
    -- For Target/Focus use the same technique as current Forever unit-frame
    -- addons: normalize scale, set the real button dimensions, then let the
    -- post-UpdateAuras hook reapply after Blizzard refreshes its layout.
    if src == 'TARGET' or src == 'FOCUS' then
        -- The live Blizzard TargetFrame_UpdateAuras() explicitly calls
        -- SetWidth/SetHeight on TargetFrameBuffN / TargetFrameDebuffN. Apply
        -- our chosen size directly to those exact buttons AFTER Blizzard's
        -- update and normalize scale so the saved value is literal pixels.
        if button.SetScale then pcall(button.SetScale, button, 1) end
        if button.SetSize then
            pcall(button.SetSize, button, iconSize, iconSize)
        else
            if button.SetWidth then pcall(button.SetWidth, button, iconSize) end
            if button.SetHeight then pcall(button.SetHeight, button, iconSize) end
        end
        local icon = button.Icon or button.icon
        if not icon and button.GetName then
            local okName, n = pcall(button.GetName, button)
            if okName and n then icon = _G[n .. 'Icon'] end
        end
        if icon then
            if icon.ClearAllPoints then pcall(icon.ClearAllPoints, icon) end
            if icon.SetAllPoints then pcall(icon.SetAllPoints, icon, button) end
        end
        if button.SetAlpha then pcall(button.SetAlpha, button, 1) end
    elseif src == 'PLAYER' then
        -- Native AuraContainer owns all geometry and spacing.
    end

    return true
end

function AuraText:ApplyVisible()
    applyAllMinimapNativeLayouts(false)
    self:ScanAuraFrames()
    local count, playerCount, targetCount = 0, 0, 0
    for button, kind in pairs(registered) do
        if button and (not button.IsShown or button:IsShown()) then
            if applyButton(button, kind) then
                count = count + 1
                local src = sourceKind[button]
                if src == 'TARGET' or src == 'FOCUS' then targetCount = targetCount + 1 else playerCount = playerCount + 1 end
            end
        end
    end
    self._lastApplied = count
    self._lastPlayerApplied = playerCount
    self._lastTargetApplied = targetCount
    return count
end

function AuraText:GetLastAppliedCount() return tonumber(self._lastApplied) or 0 end
function AuraText:GetLastPlayerAppliedCount() return tonumber(self._lastPlayerApplied) or 0 end
function AuraText:GetLastTargetAppliedCount() return tonumber(self._lastTargetApplied) or 0 end
function AuraText:GetNamedTargetFrameCount() return tonumber(self._lastNamedTargetFound) or 0 end

local function markedNameplateKind(region)
    local depth = 0
    while region and depth < 12 do
        local okMarker, marker = pcall(function() return region.OGMNameplateAura end)
        if okMarker and marker then
            local okKind, kind = pcall(function() return region.OGMNameplateAuraKind end)
            if okKind and kind == 'BUFF' then return 'BUFF' end
            if okKind and kind == 'DEBUFF' then return 'DEBUFF' end
            return 'BUFF'
        end
        if not region.GetParent then break end
        local okParent, parent = pcall(region.GetParent, region)
        if not okParent then break end
        region = parent
        depth = depth + 1
    end
end

function AuraText:Classify(cooldown)
    return cooldownKind[cooldown]
end

function AuraText:Apply(cooldown)
    local kind = cooldownKind[cooldown]
    if kind then
        local p = cooldown.GetParent and cooldown:GetParent()
        return applyButton(p, kind)
    end

    -- Custom target/nameplate rows are styled exclusively by the normal OmniCC
    -- rule -> theme pipeline. Never apply a second font here: that old override
    -- was the reason sliders snapped back and fresh buffs reset to Blizzard style.
    if markedNameplateKind(cooldown) then return false end
    return false
end


-- Style timer text inside addon-owned/custom aura containers (for example
-- PlaterMobHealth's Forever player/NPC nameplate aura rows).  The container
-- owns icon geometry/spacing, so this deliberately changes TEXT ONLY; the
-- nameplate module applies the matching container scale separately.
local function applyExternalText(button, kind, s)
    if not button or not s then return false end
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local textSize = kind == 'DEBUFF' and s.debuff or s.buff
    local touched = false

    local duration = button.Duration or button.duration or button.TimerText or button.TimeText or button.timeText
    if duration and duration.GetFont and duration.SetFont then
        touched = setFontSize(duration, textSize) or touched
    end

    local cd = button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame
    if cd then
        cooldownKind[cd] = kind
        if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers, cd, false) end
        if cd.GetCountdownFontString then
            local ok, fs = pcall(cd.GetCountdownFontString, cd)
            if ok and fs then touched = setFontSize(fs, textSize) or touched end
        end
    end
    return touched
end

function AuraText:StyleExternalContainer(container, kind)
    -- External nameplate aura containers (Plater/Threat Plates/etc.) are discovered
    -- here even when their individual cooldown frames are anonymous. Mark every
    -- discovered cooldown explicitly as a nameplate frame so Compatibility Center
    -- can perform a TRUE release instead of relying on fragile parent/name guesses.
    if not container or not container.GetChildren then return 0 end
    local children = {container:GetChildren()}
    for _, button in ipairs(children) do
        local cd = button and (button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame)
        if cd then cd._ogmCompatScope = 'nameplates' end
    end

    -- CHECKED Nameplates means the external addon owns the complete aura row.
    -- Do not style text, force countdowns, resize, or otherwise touch its timers.
    if Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates') then return 0 end

    -- 10/10 deliberately makes the ICONS huge. Counter-scale only timer text so
    -- the cooldown number never grows to the same visual size as the icon.
    local touched = 0
    for _, button in ipairs(children) do
        local cd = button and (button.Cooldown or button.cooldown or button.CooldownFrame or button.cooldownFrame)
        if cd then
            local function shrink(fs)
                if not fs then return end
                -- Forever nameplate icons can be 3x at 10/10. Keep the native
                -- countdown physically small instead of inheriting that scale.
                if fs.GetFont and fs.SetFont then
                    local ok, path, _, flags = pcall(fs.GetFont, fs)
                    path = (ok and path) or STANDARD_TEXT_FONT
                    pcall(fs.SetFont, fs, path, 10, flags or 'OUTLINE')
                end
                if fs.SetScale then pcall(fs.SetScale, fs, 0.42) end
                if fs.SetAlpha then pcall(fs.SetAlpha, fs, 1) end
                touched=touched+1
            end
            if cd.GetCountdownFontString then local ok,fs=pcall(cd.GetCountdownFontString,cd); if ok then shrink(fs) end end
            if cd.GetRegions then
                local ok,regions=pcall(function() return {cd:GetRegions()} end)
                if ok then for _,r in ipairs(regions) do if r and r.GetObjectType then local rok,t=pcall(r.GetObjectType,r); if rok and t=='FontString' then shrink(r) end end end end
            end
        end
    end
    return touched
end

-- External Blizzard BuffFrame/DebuffFrame scale for the shared size controller.

function AuraText:GetFrameAuraEnabled(frame, kind)
    -- Backward compatibility: GetFrameAuraEnabled(kind) means SELF.
    if kind == nil then kind, frame = frame, 'SELF' end
    frame = tostring(frame or 'SELF'):upper()
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER')
    if not s then return true end
    -- Do NOT use Lua's `cond and falseValue or trueValue` idiom here. When a
    -- DEBUFF switch is false it falls through to the BUFF value, which made a
    -- standalone Debuffs OFF read back as ON whenever Buffs were still ON.
    if frame == 'TARGET' then
        if kind == 'DEBUFF' then return s.targetFrameDebuffsEnabled ~= false end
        return s.targetFrameBuffsEnabled ~= false
    end
    if kind == 'DEBUFF' then return s.selfFrameDebuffsEnabled ~= false end
    return s.selfFrameBuffsEnabled ~= false
end
function AuraText:SetFrameAuraEnabled(frame, kind, enabled)
    -- Backward compatibility: SetFrameAuraEnabled(kind, enabled) means SELF.
    if enabled == nil then enabled, kind, frame = kind, frame, 'SELF' end
    frame = tostring(frame or 'SELF'):upper()
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER'); if not s then return end
    local value = enabled and true or false
    if frame == 'TARGET' then
        if kind == 'DEBUFF' then s.targetFrameDebuffsEnabled=value else s.targetFrameBuffsEnabled=value end
        if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.ApplyVisibility then Addon.ForeverTargetAuraTimers.ApplyVisibility() end
        if Addon.ForeverTargetAuraTimers then
            local fn=Addon.ForeverTargetAuraTimers.Apply or Addon.ForeverTargetAuraTimers.Refresh
            if fn then pcall(fn) end
        end
    else
        if kind == 'DEBUFF' then s.selfFrameDebuffsEnabled=value else s.selfFrameBuffsEnabled=value end
        if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.RequestApply then Addon.ForeverPlayerFrameAuras.RequestApply() end
    end
    -- Ellesmere compatibility must consume the exact same four switches live.
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls,Addon) end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.ApplyTheme then pcall(Addon.ForeverTargetAuraTimers.ApplyTheme) end
end


function AuraText:GetSelfFrameOffset()
    local s=scopedSettings('PLAYER'); return tonumber(s and s.selfFrameX) or 0, tonumber(s and s.selfFrameY) or 0
end
function AuraText:SetSelfFrameOffset(x,y)
    local s=scopedSettings('PLAYER'); if not s then return end
    s.selfFrameX=math.max(-200,math.min(200,tonumber(x) or 0)); s.selfFrameY=math.max(-200,math.min(200,tonumber(y) or 0))
    if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.Reposition then Addon.ForeverPlayerFrameAuras.Reposition() end
end
function AuraText:NudgeSelfFrame(dx,dy)
    local x,y=self:GetSelfFrameOffset(); self:SetSelfFrameOffset(x+(tonumber(dx) or 0),y+(tonumber(dy) or 0))
end
function AuraText:GetTargetFrameOffset()
    local s=scopedSettings('PLAYER'); return tonumber(s and s.targetFrameX) or 0, tonumber(s and s.targetFrameY) or 0
end
function AuraText:SetTargetFrameOffset(x,y)
    local s=scopedSettings('PLAYER'); if not s then return end
    s.targetFrameX=math.max(-200,math.min(200,tonumber(x) or 0)); s.targetFrameY=math.max(-200,math.min(200,tonumber(y) or 0))
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.Reposition then Addon.ForeverTargetAuraTimers.Reposition() end
end
function AuraText:NudgeTargetFrame(dx,dy)
    local x,y=self:GetTargetFrameOffset(); self:SetTargetFrameOffset(x+(tonumber(dx) or 0),y+(tonumber(dy) or 0))
end
-- Independent unit-frame aura layout, saved alongside existing player settings.
function AuraText:GetFrameAuraLayout(frame,kind)
    local s=scopedSettings('PLAYER'); frame=frame=='TARGET' and 'TARGET' or 'SELF'; kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'
    local key='unitAura'..frame..kind
    return tonumber(s and s[key..'X']) or 0, tonumber(s and s[key..'Y']) or 0, s and s['unitAura'..frame..'Swap']==true
end
function AuraText:SetFrameAuraLayout(frame,kind,x,y)
    local s=scopedSettings('PLAYER'); if not s then return end
    frame=frame=='TARGET' and 'TARGET' or 'SELF'; kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'
    local key='unitAura'..frame..kind
    s[key..'X']=math.max(-200,math.min(200,tonumber(x) or 0))
    s[key..'Y']=math.max(-200,math.min(200,tonumber(y) or 0))
    local mod=frame=='TARGET' and Addon.ForeverTargetAuraTimers or Addon.ForeverPlayerFrameAuras
    if mod and mod.Reposition then mod.Reposition() end
end
function AuraText:NudgeFrameAuraLayout(frame,kind,dx,dy)
    local x,y=self:GetFrameAuraLayout(frame,kind)
    self:SetFrameAuraLayout(frame,kind,x+(tonumber(dx) or 0),y+(tonumber(dy) or 0))
end
function AuraText:GetFrameAuraPlacement(frame)
    local s=scopedSettings('PLAYER')
    frame=frame=='TARGET' and 'TARGET' or 'SELF'
    return s and s['unitAura'..frame..'Placement']=='TOP' and 'TOP' or 'BOTTOM'
end
function AuraText:SetFrameAuraPlacement(frame,placement)
    local s=scopedSettings('PLAYER'); if not s then return end
    frame=frame=='TARGET' and 'TARGET' or 'SELF'
    s['unitAura'..frame..'Placement']=placement=='TOP' and 'TOP' or 'BOTTOM'
    local mod=frame=='TARGET' and Addon.ForeverTargetAuraTimers or Addon.ForeverPlayerFrameAuras
    if mod and mod.Reposition then mod.Reposition() end
    -- Secure AuraContainer flow direction is set at creation. Reposition alone
    -- leaves wrapped rows growing in the PREVIOUS direction after TOP/BOTTOM.
    -- RequestApply already defers protected rebuilds until combat ends.
    if mod and mod.RequestApply then mod.RequestApply() end
    if frame=='TARGET' and Addon.ForeverNativeTargetAuras and Addon.ForeverNativeTargetAuras~=mod
        and Addon.ForeverNativeTargetAuras.RequestApply then
        Addon.ForeverNativeTargetAuras.RequestApply()
    end
end
function AuraText:ToggleFrameAuraPlacement(frame)
    self:SetFrameAuraPlacement(frame,self:GetFrameAuraPlacement(frame)=='TOP' and 'BOTTOM' or 'TOP')
end
function AuraText:ToggleFrameAuraOrder(frame)
    local s=scopedSettings('PLAYER'); if not s then return end
    frame=frame=='TARGET' and 'TARGET' or 'SELF'
    local key='unitAura'..frame..'Swap'; s[key]=not s[key]
    local mod=frame=='TARGET' and Addon.ForeverTargetAuraTimers or Addon.ForeverPlayerFrameAuras
    if mod and mod.Reposition then
        -- AuraContainer anchors may be protected during combat. Defer the
        -- re-anchor rather than silently leaving the old order on screen.
        if InCombatLockdown and InCombatLockdown() then
            if not self._orderRefreshFrame then
                local f=CreateFrame('Frame')
                f:RegisterEvent('PLAYER_REGEN_ENABLED')
                f:SetScript('OnEvent',function(frame)
                    frame:UnregisterEvent('PLAYER_REGEN_ENABLED')
                    local m1=Addon.ForeverPlayerFrameAuras
                    local m2=Addon.ForeverTargetAuraTimers
                    if m1 and m1.Reposition then m1.Reposition() end
                    if m2 and m2.Reposition then m2.Reposition() end
                    self._orderRefreshFrame=nil
                end)
                self._orderRefreshFrame=f
            end
        else
            mod.Reposition()
        end
    end
end
function AuraText:GetFrameCountdownTextEnabled(kind)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER')
    if not s then return true end
    if kind == 'DEBUFF' then return s.frameDebuffCountdownTextEnabled ~= false end
    return s.frameBuffCountdownTextEnabled ~= false
end
local VALID_TEXT_ANCHORS = {TOP=true,CENTER=true,BOTTOM=true}
function AuraText:GetFrameCountdownTextAnchor(kind)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER')
    local key=kind=='DEBUFF' and 'frameDebuffCountdownTextAnchor' or 'frameBuffCountdownTextAnchor'
    local point=s and s[key] or 'BOTTOM'
    return VALID_TEXT_ANCHORS[point] and point or 'BOTTOM'
end
function AuraText:GetFrameCountdownTextOffset(kind)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER'); if not s then return 0,0 end
    if kind=='DEBUFF' then return tonumber(s.frameDebuffCountdownTextX) or 0, tonumber(s.frameDebuffCountdownTextY) or 0 end
    return tonumber(s.frameBuffCountdownTextX) or 0, tonumber(s.frameBuffCountdownTextY) or 0
end
function AuraText:SetFrameCountdownTextOffset(kind,x,y)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER'); if not s then return end
    x=math.max(-30,math.min(30,tonumber(x) or 0)); y=math.max(-30,math.min(30,tonumber(y) or 0))
    if kind=='DEBUFF' then s.frameDebuffCountdownTextX=x; s.frameDebuffCountdownTextY=y else s.frameBuffCountdownTextX=x; s.frameBuffCountdownTextY=y end
    local pm=Addon.ForeverPlayerFrameAuras; if pm and pm.RequestApply then pm.RequestApply() end
    local tm=Addon.ForeverTargetAuraTimers; if tm and tm.RequestApply then tm.RequestApply() end
    local nt=Addon.ForeverNativeTargetAuras; if nt and nt.RequestApply then nt.RequestApply() end
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls,Addon) end
end
function AuraText:SetFrameCountdownTextAnchor(kind,point)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    point=tostring(point or 'BOTTOM'):upper()
    if not VALID_TEXT_ANCHORS[point] then point='BOTTOM' end
    local s=scopedSettings('PLAYER'); if not s then return end
    s[kind=='DEBUFF' and 'frameDebuffCountdownTextAnchor' or 'frameBuffCountdownTextAnchor']=point
    local pm=Addon.ForeverPlayerFrameAuras
    if pm and pm.RequestApply then pm.RequestApply() end
    local tm=Addon.ForeverTargetAuraTimers
    if tm and tm.RequestApply then tm.RequestApply() elseif tm and tm.ApplyTheme then tm.ApplyTheme() end
    local nt=Addon.ForeverNativeTargetAuras
    if nt and nt.RequestApply then nt.RequestApply() elseif nt and nt.ApplyTheme then nt.ApplyTheme() end
end
function AuraText:SetFrameCountdownTextEnabled(kind,v)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s=scopedSettings('PLAYER'); if not s then return end
    if kind == 'DEBUFF' then
        s.frameDebuffCountdownTextEnabled = v and true or false
        s.selfDebuffCountdownTextEnabled = s.frameDebuffCountdownTextEnabled
    else
        s.frameBuffCountdownTextEnabled = v and true or false
    end
    local pm=Addon.ForeverPlayerFrameAuras
    if pm and pm.RequestApply then pm.RequestApply() end
    local tm=Addon.ForeverTargetAuraTimers
    if tm and tm.RequestApply then tm.RequestApply()
    elseif tm and tm.ApplyTheme then tm.ApplyTheme()
    elseif tm and tm.ApplyVisibility then tm.ApplyVisibility() end
    local nt=Addon.ForeverNativeTargetAuras
    if nt and nt.RequestApply then nt.RequestApply()
    elseif nt and nt.ApplyTheme then nt.ApplyTheme()
    elseif nt and nt.ApplyVisibility then nt.ApplyVisibility() end
    -- Ellesmere owns its live AuraKit PLAYER/TARGET buttons. Mirror the same
    -- Text ON/OFF state immediately instead of waiting for another compat pass.
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls, Addon) end
    self:ApplyVisible()
end
-- Backwards-compatible aliases for older Config builds.
function AuraText:GetSelfDebuffCountdownTextEnabled()
    return self:GetFrameCountdownTextEnabled('DEBUFF')
end
function AuraText:SetSelfDebuffCountdownTextEnabled(v)
    self:SetFrameCountdownTextEnabled('DEBUFF',v)
end
function AuraText:GetInheritBlizzardDebuffBorder()
    local s=scopedSettings('PLAYER'); return not s or s.inheritBlizzardDebuffBorder ~= false
end
function AuraText:SetInheritBlizzardDebuffBorder(v)
    local s=scopedSettings('PLAYER'); if not s then return end
    s.inheritBlizzardDebuffBorder = v and true or false
    if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.RequestApply then Addon.ForeverPlayerFrameAuras.RequestApply() end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
end

-- Blizzard BuffFrame/DebuffFrame beside the minimap keeps Blizzard's native
-- geometry. GODMODE may style its duration text, but frame-aura size controls
-- must never resize/scale these external buttons.
function AuraText:GetExternalIconScale(kind) return 1 end
function AuraText:GetExternalIconSize(kind) return nil end

-- TARGET/nameplate text is persisted directly in AceDB themes.
-- Only icon size remains in the tiny dedicated SavedVariables table.

function AuraText:GetScopedTextSize(scope, kind)
    local p = Addon.db and Addon.db.profile
    local af = p and p.godmodeAutoFitEnabled and p.themes and p.themes.godmode_autofit
    if af then return math.max(1, math.min(15, 5 + 10 * (math.max(0,math.min(99,tonumber(af.fontSize) or 99))/99))) end
    -- One compact frame controller: SELF and TARGET always use the same value.
    -- Do not source this from the global Theme fontSize: that also styles action
    -- bars/nameplates and was the reason action-bar cooldown numbers shrank.
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    local s = scopedSettings('PLAYER')
    if not s then return kind == 'DEBUFF' and DEFAULT_TEXT_DEBUFF or DEFAULT_TEXT_BUFF end
    return kind == 'DEBUFF' and s.debuff or s.buff
end
function AuraText:GetScopedIconSize(scope, kind)
    scope = (scope == 'TARGET' or scope == 'FOCUS') and 'TARGET' or 'PLAYER'
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    -- SELF and TARGET deliberately share the compact frame geometry.
    local s = scopedSettings('PLAYER')
    if not s then return kind == 'DEBUFF' and DEFAULT_ICON_DEBUFF or DEFAULT_ICON_BUFF end
    return kind == 'DEBUFF' and s.debuffIcon or s.buffIcon
end
-- Backwards-compatible methods = YOUR/PLAYER auras.
function AuraText:GetTextSize(kind) return self:GetScopedTextSize('PLAYER', kind) end
function AuraText:GetSize(kind) return self:GetTextSize(kind) end
function AuraText:GetIconSize(kind) return self:GetScopedIconSize('PLAYER', kind) end

function AuraText:SetScopedTextSize(scope, kind, value)
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    value = clamp(value, MIN_TEXT, MAX_TEXT, DEFAULT_TEXT_BUFF)
    local ps=scopedSettings('PLAYER')
    if ps then ps[kind=='DEBUFF' and 'debuff' or 'buff']=value end
    -- Rebuild ONLY addon-owned SELF/TARGET rows. Never write Theme.fontSize here:
    -- Theme.fontSize is shared with action bars/nameplates.
    if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.RequestApply then Addon.ForeverPlayerFrameAuras.RequestApply() end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply()
    elseif Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.ApplyTheme then Addon.ForeverTargetAuraTimers.ApplyTheme() end
    -- Both renderers can be loaded: never skip the visible native target row.
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls,Addon) end
    self:ShowPreview('PLAYER')
end

function AuraText:SetScopedIconSize(scope, kind, value)
    scope = (scope == 'TARGET' or scope == 'FOCUS') and 'TARGET' or 'PLAYER'
    kind = kind == 'DEBUFF' and 'DEBUFF' or 'BUFF'
    value=clamp(value,MIN_ICON,MAX_ICON,DEFAULT_ICON_BUFF)

    -- Same single controller for SELF + TARGET icon geometry.
    local key=kind=='DEBUFF' and 'debuffIcon' or 'buffIcon'
    local ps=scopedSettings('PLAYER'); if ps then ps[key]=value end

    if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.RequestApply then Addon.ForeverPlayerFrameAuras.RequestApply() end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply()
    elseif Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.ApplyTheme then Addon.ForeverTargetAuraTimers.ApplyTheme() end
    -- Both renderers can be loaded: never skip the visible native target row.
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls,Addon) end
    self:ShowPreview(scope)
end

function AuraText:GetMinimapTextSize(kind)
    kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'; local m=minimapSettings()
    local v=m and (kind=='DEBUFF' and m.debuff or m.buff)
    return v ~= nil and v or DEFAULT_MINIMAP_TEXT_BUFF
end
function AuraText:IsMinimapControlEnabled()
    local m=minimapSettings()
    return not m or m.controlEnabled ~= false
end
function AuraText:SetMinimapControlEnabled(enabled)
    local m=minimapSettings(); if not m then return end
    m.controlEnabled = enabled and true or false
    -- ON  = explicit GODMODE icon scale, still laid out by Blizzard's grid.
    -- OFF = immediately restore the user's saved Blizzard Edit Mode icon size.
    applyAllMinimapNativeLayouts(true)
    self:ApplyVisible()
end

function AuraText:GetMinimapIconSize(kind)
    kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'; local m=minimapSettings()
    local v=m and (kind=='DEBUFF' and m.debuffIcon or m.buffIcon)
    -- If GODMODE has no explicit override, report Blizzard's REAL current Edit
    -- Mode size instead of pretending it is always 30px. The first +/- click
    -- therefore starts exactly from what the player is already seeing.
    return v ~= nil and v or readBlizzardMinimapIconSize(kind)
end
function AuraText:SetMinimapTextSize(kind,value)
    kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'; local m=minimapSettings(); if not m then return end
    m[kind=='DEBUFF' and 'debuff' or 'buff']=clamp(value,MIN_TEXT,MAX_TEXT,DEFAULT_MINIMAP_TEXT_BUFF)
    self:ApplyVisible()
end
local function requestNativeMinimapLayout(kind)
    if kind then applyMinimapNativeLayout(kind,true) else applyAllMinimapNativeLayouts(true) end
end

function AuraText:SetMinimapIconSize(kind,value)
    kind=kind=='DEBUFF' and 'DEBUFF' or 'BUFF'; local m=minimapSettings(); if not m then return end
    m[kind=='DEBUFF' and 'debuffIcon' or 'buffIcon']=clamp(value,MIN_MINIMAP_ICON,MAX_MINIMAP_ICON,DEFAULT_MINIMAP_ICON_BUFF)
    -- Apply through the exact Blizzard AuraContainer.iconScale + UpdateGridLayout
    -- path first; ApplyVisible then reapplies timer appearance only.
    requestNativeMinimapLayout(kind)
    self:ApplyVisible()
end
function AuraText:NudgeMinimapTextSize(kind,delta) self:SetMinimapTextSize(kind,self:GetMinimapTextSize(kind)+(tonumber(delta) or 0)) end
function AuraText:NudgeMinimapIconSize(kind,delta) self:SetMinimapIconSize(kind,self:GetMinimapIconSize(kind)+(tonumber(delta) or 0)) end
function AuraText:ResetMinimap()
    local m=minimapSettings(); if not m then return end
    -- nil = Blizzard owns the native minimap aura geometry/text again.
    m.buff,m.debuff=nil,nil
    m.buffIcon,m.debuffIcon=nil,nil
    requestNativeMinimapLayout()
    self:ApplyVisible()
end

-- Explicit user action only. Never called by migrations/login/update.
-- Resets aura SIZES only; positions, visibility, colors, rules and profiles survive.
function AuraText:ResetAllAuraSizesToBlizzard()
    local s=scopedSettings('PLAYER')
    if s then
        -- Explicitly reset BOTH kinds used by SELF and TARGET.
        s.buff,s.debuff=DEFAULT_TEXT_BUFF,DEFAULT_TEXT_DEBUFF
        s.buffIcon,s.debuffIcon=DEFAULT_ICON_BUFF,DEFAULT_ICON_DEBUFF
    end
    -- Clear every legacy TARGET override too.  Older builds could leave these
    -- values behind even though SELF and TARGET now share the frame controller.
    local ts=targetSettings()
    if ts then ts.buffIcon,ts.debuffIcon=DEFAULT_ICON_BUFF,DEFAULT_ICON_DEBUFF end
    local profile=Addon.db and Addon.db.profile
    local tf=profile and profile.godmodeModuleText and profile.godmodeModuleText.targetFrame
    if tf then tf.buffSize,tf.debuffSize=DEFAULT_TEXT_BUFF,DEFAULT_TEXT_DEBUFF end

    -- Minimap is independent. nil means the hard Blizzard 30x30/native-font
    -- restoration path in applyButton(), never a cached GODMODE-modified size.
    local m=minimapSettings()
    if m then m.buff,m.debuff,m.buffIcon,m.debuffIcon=nil,nil,nil,nil end

    -- Rebuild SELF secure aura rows so both buff/debuff geometry is recreated.
    if Addon.ForeverPlayerFrameAuras and Addon.ForeverPlayerFrameAuras.RequestApply then Addon.ForeverPlayerFrameAuras.RequestApply() end
    -- Force Blizzard TargetFrame to refresh its real aura buttons first, then
    -- reapply the GODMODE target renderer/holders on the next frame.
    if _G.TargetFrame_UpdateAuras and _G.TargetFrame then pcall(_G.TargetFrame_UpdateAuras,_G.TargetFrame) end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
    -- The visible standalone Forever TARGET row is ForeverNativeTargetAuras. Its
    -- secure AuraContainer buttons bake icon/text geometry in initializeFrame,
    -- so a reset MUST rebuild that renderer too (BUFFS + DEBUFFS).
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
    if Addon.SyncEllesmereAuraControls then pcall(Addon.SyncEllesmereAuraControls,Addon) end
    self:ApplyVisible()
    if C_Timer and C_Timer.After then
        C_Timer.After(0,function()
            if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
            if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.RequestApply then Addon.ForeverTargetAuraTimers.RequestApply() end
            if Addon.ForeverAuraText then Addon.ForeverAuraText:ApplyVisible() end
        end)
    end
    self:ShowPreview('PLAYER')
end

function AuraText:NudgeScopedTextSize(scope,kind,delta)
    self:SetScopedTextSize(scope,kind,self:GetScopedTextSize(scope,kind)+(tonumber(delta) or 0))
end
function AuraText:NudgeScopedIconSize(scope,kind,delta)
    self:SetScopedIconSize(scope,kind,self:GetScopedIconSize(scope,kind)+(tonumber(delta) or 0))
end
function AuraText:ResetScoped(scope, kind)
    scope = (scope == 'TARGET' or scope == 'FOCUS') and 'TARGET' or 'PLAYER'
    kind = kind == 'DEBUFF' and 'DEBUFF' or (kind == 'BUFF' and 'BUFF' or nil)
    if scope == 'TARGET' then
        local function resetOne(k)
            local theme = getTargetTheme(k)
            if theme then
                theme.enabled = true; theme.themeText = true; theme.drawText = 'always'
                theme.scaleText = false; theme.minScale = 0; theme.minDuration = 0; theme.fontSize = 22
            end
            local s = targetSettings()
            if k == 'DEBUFF' then s.debuffIcon = 32 else s.buffIcon = 32 end
        end
        if kind then resetOne(kind) else resetOne('BUFF'); resetOne('DEBUFF') end
        if Addon.Refresh then Addon:Refresh() end
        if Addon.ForeverNameplates and Addon.ForeverNameplates.Refresh then pcall(Addon.ForeverNameplates.Refresh) end
    else
        local s = scopedSettings('PLAYER'); if not s then return end
        if kind == 'BUFF' then s.buff,s.buffIcon=DEFAULT_TEXT_BUFF,DEFAULT_ICON_BUFF
        elseif kind == 'DEBUFF' then s.debuff,s.debuffIcon=DEFAULT_TEXT_DEBUFF,DEFAULT_ICON_DEBUFF
        else s.buff,s.debuff=DEFAULT_TEXT_BUFF,DEFAULT_TEXT_DEBUFF; s.buffIcon,s.debuffIcon=DEFAULT_ICON_BUFF,DEFAULT_ICON_DEBUFF end
        reapplyOnce()
    end
    self:ShowPreview(scope)
end

-- Existing API remains YOUR/PLAYER controls so nothing already working breaks.
function AuraText:SetTextSize(kind,value) self:SetScopedTextSize('PLAYER',kind,value) end
function AuraText:SetSize(kind,value) self:SetTextSize(kind,value) end
function AuraText:NudgeSize(kind,delta) self:NudgeScopedTextSize('PLAYER',kind,delta) end
function AuraText:NudgeTextSize(kind,delta) self:NudgeScopedTextSize('PLAYER',kind,delta) end
function AuraText:SetIconSize(kind,value) self:SetScopedIconSize('PLAYER',kind,value) end
function AuraText:NudgeIconSize(kind,delta) self:NudgeScopedIconSize('PLAYER',kind,delta) end
function AuraText:Reset(kind) self:ResetScoped('PLAYER',kind) end


-- Legacy floating Aura Size / Timer Preview removed.
-- The Config panel now has one persistent LIVE AURA PREVIEW, so size +/- must never
-- spawn a second temporary window. Keep these methods as no-ops for old callers.
function AuraText:ShowPreview(scope) end
function AuraText:HidePreview() end

local refreshQueued = false
reapplyOnce = function()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if Addon.ForeverAuraText then Addon.ForeverAuraText:ApplyVisible() end
    end)
end

local function installHooks()
    hooked = true
end

local ef = CreateFrame('Frame')
ef:RegisterEvent('PLAYER_ENTERING_WORLD')
ef:RegisterEvent('PLAYER_REGEN_ENABLED')
ef:RegisterEvent('UNIT_AURA')
-- New and recycled Blizzard aura buttons are laid out asynchronously. A single
-- deferred event-driven pass re-discovers them after Blizzard updates the pool.
-- No OnUpdate polling, no Blizzard layout hooks, and no protected grid writes.
local auraReflowQueued = false
local function queuePlayerAuraReflow()
    if auraReflowQueued then return end
    auraReflowQueued = true
    C_Timer.After(0, function()
        auraReflowQueued = false
        if InCombatLockdown and InCombatLockdown() then return end
        if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then return end
        if Addon.ForeverAuraText then Addon.ForeverAuraText:ApplyVisible() end
    end)
end
ef:SetScript('OnEvent', function(_, event, unit)
    if event == 'UNIT_AURA' then
        if unit == 'player' and (AuraText:IsMinimapControlEnabled() or minimapThemeEnabled()) then
            queuePlayerAuraReflow()
        end
        return
    end
    -- A size click made during combat is deliberately deferred because touching
    -- Blizzard aura layout there is unsafe. Reconcile immediately when combat
    -- ends; PLAYER_ENTERING_WORLD uses the same path on login/reload.
    installHooks()
    -- Only reconcile geometry at login/combat exit, never from aura Update.
    applyAllMinimapNativeLayouts(false)
    reapplyOnce()
end)

C_Timer.After(1, function()
    installHooks()
    -- Clear legacy experimental text override state once. Text now lives only
    -- in AceDB themes, so nothing can snap the Themes panel back afterward.
    targetSettings()
    reapplyOnce()
end)

-- Reconcile immediately after the native Edit Mode panel is dismissed.
-- This only reads native aura button positions and moves GODMODE icon artwork;
-- it does not hook Blizzard layout methods or write secure container settings.
local editModeWasVisible = false
local function onEditModeVisibilityChanged()
    local manager = _G.EditModeManagerFrame
    local visible = manager and manager.IsShown and manager:IsShown() or false
    if visible then
        editModeWasVisible = true
        -- Legacy overlay hit buttons were removed in V30; native secure buttons own clicks.
    elseif editModeWasVisible then
        editModeWasVisible = false
        if AuraText:IsMinimapControlEnabled() then
            C_Timer.After(0, function()
                if InCombatLockdown and InCombatLockdown() then return end
                if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return end
                AuraText:ScanAuraFrames()
                applyAllMinimapNativeLayouts(false)
            end)
        end
    end
end
local editModeWatcher = CreateFrame('Frame')
editModeWatcher:RegisterEvent('EDIT_MODE_LAYOUTS_UPDATED')
editModeWatcher:RegisterEvent('PLAYER_ENTERING_WORLD')
editModeWatcher:SetScript('OnEvent', onEditModeVisibilityChanged)
-- Watch only Edit Mode transitions; never hook its protected frame methods.
editModeWatcher:SetScript('OnUpdate', function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0
    onEditModeVisibilityChanged()
end)

-- Lightweight minimap-only reconciliation: Blizzard can silently rebuild its
-- aura grid when Edit Mode closes or an aura pool recycles. This does not hook
-- Blizzard methods and never visits nameplates or runs during combat/Edit Mode.
local lastMinimapReconcile = false
C_Timer.NewTicker(1.0, function()
    if not AuraText:IsMinimapControlEnabled() then
        if lastMinimapReconcile then
            -- Legacy overlay hit buttons were removed in V30; native secure buttons own clicks.
        end
        lastMinimapReconcile = false
        return
    end
    if InCombatLockdown and InCombatLockdown() then return end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
        -- Legacy overlay hit buttons were removed in V30; native secure buttons own clicks.
        lastMinimapReconcile = false
        return
    end
    lastMinimapReconcile = true
    AuraText:ScanAuraFrames()
    applyAllMinimapNativeLayouts(false)
end)
