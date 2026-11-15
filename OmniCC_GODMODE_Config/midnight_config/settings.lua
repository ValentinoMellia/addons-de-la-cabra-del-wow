local _, Addon = ...
local OmniCC_GODMODE = _G.OmniCC_GODMODE

-- Addon-level callbacks for data → UI communication
Mixin(Addon, CallbackRegistryMixin)
CallbackRegistryMixin.OnLoad(Addon)

Addon:GenerateCallbackEvents {
    "OnThemeListChanged",
    "OnThemeColorsChanged",
}

function Addon:GetThemes()
    return OmniCC_GODMODE.db.profile.themes
end

function Addon:HasTheme(themeID)
    return rawget(OmniCC_GODMODE.db.profile.themes, themeID) ~= nil
end

function Addon:CreateTheme(name, baseThemeID)
    local key = "custom_" .. name
    if self:HasTheme(key) then
        return nil
    end

    if baseThemeID and self:HasTheme(baseThemeID) then
        local theme = CopyTable(OmniCC_GODMODE.db.profile.themes[baseThemeID])

        theme.base = baseThemeID
        theme.displayName = name

        OmniCC_GODMODE.db.profile.themes[key] = theme
    else
        -- AceDB ['**'] defaults auto-create this table on first index
        OmniCC_GODMODE.db.profile.themes[key].displayName = name
    end

    OmniCC_GODMODE:Refresh()
    self:TriggerEvent("OnThemeListChanged", key)
    return key
end

function Addon:DeleteTheme(themeID)
    if themeID == "default" then
        return false
    end

    OmniCC_GODMODE.db.profile.themes[themeID] = nil

    for _, settings in pairs(OmniCC_GODMODE.db.profile.rules) do
        if settings.theme == themeID then
            settings.theme = "default"
        end
    end

    OmniCC_GODMODE:Refresh()
    self:TriggerEvent("OnThemeListChanged")
    return true
end

function Addon:ResetTheme(themeID)
    if not self:HasTheme(themeID) then
        return false
    end

    local theme = OmniCC_GODMODE.db.profile.themes[themeID]
    local baseThemeID = theme.base
    local displayName = theme.displayName

    OmniCC_GODMODE.db.profile.themes[themeID] = nil
    return self:CreateTheme(displayName or themeID, baseThemeID)
end


local auraRefreshSerial = 0
local function RefreshUnifiedAuraThemeNow(themeID)
    local G = OmniCC_GODMODE
    if not G then return end
    local forever=(OmniCC_GODMODE_ClientBackend == 'Forever' or OmniCC_GODMODE_ForeverEngineLoaded)
    local at=forever and G.ForeverAuraText or G.MidnightAuraText
    local pf=forever and G.ForeverPlayerFrameAuras or G.MidnightPlayerFrameAuras
    local tf=forever and G.ForeverTargetAuraTimers or G.MidnightTargetAuraTimers
    local native=forever and G.ForeverNativeTargetAuras or G.MidnightNativeTargetAuras
    if at and at.ApplyVisible then pcall(at.ApplyVisible,at) end
    if pf then
        local fn=pf.RefreshThemeAppearance or pf.ApplyThemeNow or pf.ApplyTheme or pf.Apply or pf.RequestApply
        if fn then pcall(fn,pf) end
    end
    if tf then
        local fn=tf.RefreshThemeAppearance or tf.ApplyThemeNow or tf.ApplyTheme or tf.Apply or tf.RequestApply or tf.Refresh
        if fn then pcall(fn,tf) end
    end
    if native and native ~= tf then
        local fn=native.RefreshThemeAppearance or native.ApplyThemeNow or native.ApplyTheme or native.RequestApply or native.Refresh
        if fn then pcall(fn,native) end
    end
    -- Midnight's secure DurationText color curve is captured at Bind time.
    -- Restyling a FontString cannot replace that curve. Recreate the two
    -- GODMODE-owned aura containers once after a coalesced theme edit, never
    -- from the cooldown or nameplate hot path. The Target bridge aliases the
    -- same owner, so rebuild it only once.
    -- Only native aura theme edits require a secure duration-curve rebind.
    -- Do not destroy/recreate frame aura containers for unrelated theme sliders.
    if themeID == 'auras' and not forever then
        if pf and pf.RequestApply then pcall(pf.RequestApply) end
        local owner=native or tf
        if owner and owner.RequestApply then pcall(owner.RequestApply) end
    end
    local np=forever and G.ForeverNameplates or G.MidnightNameplates
    -- NPC appearance is refreshed by QueueNameplateThemeAppearanceRefresh; do not traverse pools twice.
    if G.EnemyCooldowns and G.EnemyCooldowns.RefreshThemeAppearance then pcall(G.EnemyCooldowns.RefreshThemeAppearance,G.EnemyCooldowns) end
    for _,key in ipairs({'ForeverTargetPortrait','MidnightTargetPortrait','ForeverSelfCooldowns','MidnightSelfCooldowns'}) do
        local portrait=G[key]
        if portrait and portrait.RefreshThemeAppearance then pcall(portrait.RefreshThemeAppearance,portrait) end
    end
    -- Midnight portrait AuraContainers capture native countdown color curves at
    -- creation. Appearance-only styling cannot replace an already-bound curve.
    -- Rebind ONLY the two portrait owners after a coalesced Action Bars edit.
    -- No periodic polling and no global aura/nameplate refresh.
    if themeID == 'default' and not forever then
        for _,key in ipairs({'MidnightSelfCooldowns','MidnightTargetPortrait'}) do
            local portrait=G[key]
            if portrait and portrait.Refresh then
                if InCombatLockdown and InCombatLockdown() then
                    portrait._ogmPortraitThemeRebindPending=true
                else
                    pcall(portrait.Refresh,portrait)
                    portrait._ogmPortraitThemeRebindPending=nil
                end
            end
        end
    end
    -- The action-button direct styling path has its own native FontStrings.
    -- A shared Auto-Fit color edit must invalidate that path too, not just
    -- player/target aura and NPC renderers. This runs once per coalesced edit,
    -- never from the cooldown SetCooldown hotpath.
    if themeID == 'godmode_autofit' and G.db and G.db.profile
        and G.db.profile.godmodeAutoFitEnabled and G.Refresh then
        G:Refresh()
    end
    -- Cooperative TPerl-only live refresh. Color-row edits use the queued
    -- unified path (not the Themes tab property callback), so the bridge
    -- otherwise updates only on reload. Do not touch TPerl-owned durations.
    local refreshTPerl = _G.TPerl_GODMODE_RefreshDurationTheme
    if type(refreshTPerl) == 'function' then pcall(refreshTPerl) end
    -- Do NOT refresh the whole nameplate renderer here. Nameplates own their own
    -- theme and a full refresh on every color-picker mouse move caused the huge lag.
end
local function QueueUnifiedAuraThemeRefresh(themeID)
    auraRefreshSerial = auraRefreshSerial + 1
    local token=auraRefreshSerial
    C_Timer.After(0.22,function()
        if token==auraRefreshSerial then RefreshUnifiedAuraThemeNow(themeID) end
    end)
end

-- Coalesce rapid color-picker callbacks into one nameplate appearance pass.
-- Save the selected value immediately; never queue an aura scan/rebuild.
local nameplateThemeRefreshSerial = 0
local function QueueNameplateThemeAppearanceRefresh()
    nameplateThemeRefreshSerial = nameplateThemeRefreshSerial + 1
    local token = nameplateThemeRefreshSerial
    C_Timer.After(0.24, function()
        if token ~= nameplateThemeRefreshSerial then return end
        local G = OmniCC_GODMODE
        if not G then return end
        local np = (OmniCC_GODMODE_ClientBackend == 'Forever' or OmniCC_GODMODE_ForeverEngineLoaded)
            and G.ForeverNameplates or G.MidnightNameplates
        if np and np.RefreshThemeAppearance then
            np:RefreshThemeAppearance()
        end
    end)
end

function Addon:SetThemeProperty(themeID, property, value)
    if property == 'fontSize' then
        value = math.max(0, math.min(25, tonumber(value) or 0))
    end
    local theme = OmniCC_GODMODE.db.profile.themes[themeID]
    local oldValue = theme[property]

    if oldValue ~= value then
        theme[property] = value
        -- Buffs & Debuffs uses native AuraButton bindings. A global OmniCC refresh
        -- here is both unnecessary and extremely expensive while dragging colors.
        -- Nameplate appearance is a visual-only edit. Never invoke the global
        -- cooldown refresh or the nameplate aura rebind/repopulation path here:
        -- a color picker can emit many changes per second.
        if themeID == 'nameplates' or (themeID == 'godmode_autofit' and OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled) then
            -- Shared Auto-Fit edits must reach the native NPC aura renderer,
            -- not only the global cooldown engine and player/target aura frames.
            QueueNameplateThemeAppearanceRefresh()
        elseif themeID ~= 'auras' then
            -- Defer heavy global refresh until the user pauses slider dragging.
            QueueUnifiedAuraThemeRefresh(themeID)
        end
        if themeID == 'godmode_autofit' or (OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled and themeID ~= 'nameplates') then
            QueueUnifiedAuraThemeRefresh(themeID)
        end
        if themeID == 'auras' then
            -- ONE SOURCE OF TRUTH FOR FRAME COUNTDOWN TEXT POSITION:
            -- Themes -> Buffs & Debuffs must drive the exact same live controller
            -- used by Buffs / Debuffs -> YOUR AURA DISPLAY.  Do not maintain a
            -- second Theme-only anchor path.
            local isForever = (OmniCC_GODMODE_ClientBackend == 'Forever' or OmniCC_GODMODE_ForeverEngineLoaded)
            local at = isForever and OmniCC_GODMODE.ForeverAuraText or OmniCC_GODMODE.MidnightAuraText
            -- Defensive fallback during early load; only one backend is normally present.
            if not at then at = OmniCC_GODMODE.MidnightAuraText or OmniCC_GODMODE.ForeverAuraText end

            if property == 'fontSize' then
                if at and at.SetScopedTextSize then
                    pcall(at.SetScopedTextSize, at, 'PLAYER', 'BUFF', value)
                    pcall(at.SetScopedTextSize, at, 'PLAYER', 'DEBUFF', value)
                end
            elseif property == 'point' then
                -- This is deliberately the SAME setter called by the working
                -- YOUR AURA DISPLAY dropdown.  It updates the saved frame setting
                -- and invokes the backend's already-proven live SELF/TARGET refresh.
                if at and at.SetFrameCountdownTextAnchor then
                    pcall(at.SetFrameCountdownTextAnchor, at, 'BUFF', value)
                    pcall(at.SetFrameCountdownTextAnchor, at, 'DEBUFF', value)
                end
            elseif property == 'offsetX' or property == 'offsetY' then
                if at and at.GetFrameCountdownTextOffset and at.SetFrameCountdownTextOffset then
                    for _,kind in ipairs({'BUFF','DEBUFF'}) do
                        local x,y=at:GetFrameCountdownTextOffset(kind)
                        if property == 'offsetX' then x=value else y=value end
                        pcall(at.SetFrameCountdownTextOffset, at, kind, x, y)
                    end
                end
            end
            QueueUnifiedAuraThemeRefresh(themeID)
        end
        return true
    end

    return false
end

function Addon:GetSortedTextColors(themeID)
    return OmniCC_GODMODE.db.profile.themes[themeID].textColors
end

function Addon:AddTextColorEntry(themeID, threshold, color)
    if not (threshold and threshold > 0) then
        return false
    end

    local entries = OmniCC_GODMODE.db.profile.themes[themeID].textColors

    local index = #entries + 1
    for i, entry in ipairs(entries) do
        if entry.threshold == threshold then
            return false
        elseif entry.threshold > threshold then
            index = i
            break
        end
    end

    tinsert(entries, index, {
        threshold = threshold,
        color = color or "FFFFFFFF"
    })

    if themeID == 'nameplates' then QueueNameplateThemeAppearanceRefresh() elseif themeID ~= 'auras' and themeID ~= 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    if themeID == 'godmode_autofit' and OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled then QueueNameplateThemeAppearanceRefresh() end
    if themeID == 'auras' or themeID == 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    self:TriggerEvent("OnThemeColorsChanged", themeID)
    return true
end

function Addon:RemoveTextColorEntry(themeID, index)
    local entries = OmniCC_GODMODE.db.profile.themes[themeID].textColors

    if index > 0 and index <= #entries then
        tremove(entries, index)
        if themeID == 'nameplates' then QueueNameplateThemeAppearanceRefresh() elseif themeID ~= 'auras' and themeID ~= 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    if themeID == 'godmode_autofit' and OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled then QueueNameplateThemeAppearanceRefresh() end
        if themeID == 'auras' or themeID == 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    self:TriggerEvent("OnThemeColorsChanged", themeID)
        return true
    end

    return false
end

function Addon:SetTextColorValue(themeID, index, color)
    local entry = OmniCC_GODMODE.db.profile.themes[themeID].textColors[index]

    if entry.color ~= color then
        entry.color = color
        if themeID == 'nameplates' then QueueNameplateThemeAppearanceRefresh() elseif themeID ~= 'auras' and themeID ~= 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    if themeID == 'godmode_autofit' and OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled then QueueNameplateThemeAppearanceRefresh() end
        if themeID == 'auras' or themeID == 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
        self:TriggerEvent("OnThemeColorsChanged", themeID)
        return true
    end

    return false
end

function Addon:SetTextColorThreshold(themeID, index, threshold)
    if not (threshold and threshold > 0) then
        return false
    end

    local entries = OmniCC_GODMODE.db.profile.themes[themeID].textColors
    for _, entry in pairs(entries) do
        if entry.threshold == threshold then
            return false
        end
    end

    entries[index].threshold = threshold
    if themeID == 'nameplates' then QueueNameplateThemeAppearanceRefresh() elseif themeID ~= 'auras' and themeID ~= 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    if themeID == 'godmode_autofit' and OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled then QueueNameplateThemeAppearanceRefresh() end
    if themeID == 'auras' or themeID == 'godmode_autofit' then QueueUnifiedAuraThemeRefresh(themeID) end
    self:TriggerEvent("OnThemeColorsChanged", themeID)
    return true
end
local function GML(text)
    local map = _G.OmniCC_GODMODE_MenuLocale
    return (map and map[text]) or text
end

