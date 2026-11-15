local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

-- Provider-local Threat Plates ownership bridge.
-- Never manipulate Threat Plates live frames/widgets.  Earlier bridge revisions
-- could leave its Aura widget hard-disabled after GODMODE released Nameplates.
local Bridge = {}
Addon.ForeverThreatPlatesBridge = Bridge

local savedEnemyBuffs, savedEnemyDebuffs, savedMaster, savedShowOmniCC
local savedTPDuration, savedTPStacks
local onlyWidgetApplied = false

local function isLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok,v=pcall(C_AddOns.IsAddOnLoaded,name); if ok then return v and true or false end
    end
    if IsAddOnLoaded then
        local ok,v=pcall(IsAddOnLoaded,name); if ok then return v and true or false end
    end
    return false
end

local function getTP()
    local a = rawget(_G, 'TidyPlatesThreat')
    local saved = rawget(_G, 'ThreatPlatesDB')
    if type(a) ~= 'table' then return nil end

    -- Threat Plates uses AceDB. The active profile is not necessarily Default,
    -- and AceDB defaults may be absent from the raw SavedVariables table.
    -- Prefer the live profile when the public addon exposes it.
    local live = type(a.db) == 'table' and a.db.profile or nil
    -- Some Threat Plates releases expose their live AceDB through the global addon.
    -- Prefer its active profile, not a stale SavedVariables profile table.
    if type(live) ~= 'table' and type(a.GetProfile) == 'function' then
        local ok, profileName = pcall(a.GetProfile, a)
        if ok and type(profileName) == 'string' and type(saved) == 'table'
            and type(saved.profiles) == 'table' then
            live = saved.profiles[profileName]
        end
    end
    if type(live) == 'table' and type(live.AuraWidget) == 'table' then
        return a, live.AuraWidget
    end

    if type(saved) ~= 'table' then return nil end
    local profiles, keys = saved.profiles, saved.profileKeys
    if type(profiles) ~= 'table' then return nil end
    local player = UnitName and UnitName('player')
    local realm = GetRealmName and GetRealmName()
    local key = type(player)=='string' and type(realm)=='string'
        and (player .. ' - ' .. realm) or nil
    local selected = type(keys)=='table' and key and keys[key] or nil
    local profile = (type(selected)=='string' and profiles[selected])
        or profiles.Default
    if type(profile) ~= 'table' then return nil end
    -- Missing AuraWidget is normal with AceDB defaults; create only the
    -- actual settings subtable, preserving every other profile preference.
    if type(profile.AuraWidget) ~= 'table' then profile.AuraWidget = {} end
    return a, profile.AuraWidget
end

local function providerEnabled()
    if _G.OmniCC_GODMODE_CooldownsOnly == true then return false end
    local cfg=Addon.GetCompatibilityProvider and Addon:GetCompatibilityProvider('threatplates')
    local center=Addon.db and Addon.db.global and Addon.db.global.compatibilityCenter
    return center and center.enabled~=false and type(cfg)=='table' and cfg.enabled==true
end

local function tpOwnsNameplates()
    return Addon.CompatibilityProviderOwnsScope
       and Addon:CompatibilityProviderOwnsScope('threatplates','nameplates')
       or false
end

local function refreshTP(a, reinitializeAuras)
    local widgets=a and a.Widgets

    -- Threat Plates' own WidgetHandler is authoritative.  Older GODMODE
    -- compatibility builds could call DisableWidget("Auras"), which removes
    -- Auras from EnabledWidgets and sets every existing widget_frame.Active=false.
    -- Merely setting AuraWidget.ON/ShowEnemy back to true cannot recover that.
    -- When TP regains Nameplate ownership, InitializeWidget("Auras") performs
    -- Threat Plates' native UpdateSettings + EnableWidget + OnUnitAdded path.
    if reinitializeAuras and widgets and type(widgets.InitializeWidget)=='function' then
        pcall(widgets.InitializeWidget,widgets,'Auras')
    elseif widgets and type(widgets.UpdateSettings)=='function' then
        pcall(widgets.UpdateSettings,widgets,'Auras')
    elseif a and type(a.UpdateSettings)=='function' then
        pcall(a.UpdateSettings,a)
    end

    if a and type(a.ForceUpdate)=='function' then pcall(a.ForceUpdate,a) end
end

local function remember(aw)
    if savedMaster==nil then savedMaster=aw.ON end
    if type(aw.Buffs)=='table' and savedEnemyBuffs==nil then savedEnemyBuffs=aw.Buffs.ShowEnemy end
    if type(aw.Debuffs)=='table' and savedEnemyDebuffs==nil then savedEnemyDebuffs=aw.Debuffs.ShowEnemy end
end

local function setEnemySwitches(aw,on)
    local changed=false
    if aw.ON~=true then aw.ON=true; changed=true end

    local buffs=type(aw.Buffs)=='table' and aw.Buffs or nil
    local debuffs=type(aw.Debuffs)=='table' and aw.Debuffs or nil

    if buffs then
        -- THREAT PLATES -> Auras -> Buffs -> ENEMY UNITS.
        if buffs.ShowEnemy~=on then buffs.ShowEnemy=on; changed=true end
        if buffs.ShowAllEnemy~=on then buffs.ShowAllEnemy=on; changed=true end
        if buffs.ShowOnEnemyNPCs~=on then buffs.ShowOnEnemyNPCs=on; changed=true end
    end

    if debuffs then
        -- THREAT PLATES -> Auras -> Debuffs -> ENEMY UNITS.
        if debuffs.ShowEnemy~=on then debuffs.ShowEnemy=on; changed=true end
        if debuffs.ShowAllEnemy~=on then debuffs.ShowAllEnemy=on; changed=true end
        if on and debuffs.ShowOnlyMine~=true then debuffs.ShowOnlyMine=true; changed=true end
    end

    return changed
end

function Bridge:IsActive()
    return isLoaded('TidyPlates_ThreatPlates') and getTP()~=nil
end

function Bridge:ApplyOwnership()
    local a,aw=getTP()
    if not aw then return false end

    -- CD Only owns GODMODE countdown styling, NOT Threat Plates options.
    -- Preserve manually selected Duration/Stack Count across login/reload.
    -- Never force ShowDuration/ShowStackCount or ShowOmniCC here.

    -- Cooldowns Only gives Threat Plates ownership of the actual aura icons.
    -- The previous providerEnabled() shortcut treated this as "provider OFF",
    -- so a prior GODMODE-owned profile could leave enemy auras disabled.
    -- Restore the native widget's enemy visibility before the countdown engine
    -- styles its existing cooldowns; do not touch duration/text settings here.
    if _G.OmniCC_GODMODE_CooldownsOnly == true then
        remember(aw)
        local changed=setEnemySwitches(aw,true)
        if changed then refreshTP(a,true) end
        return true
    end

    if not providerEnabled() then
        local changed=false
        if savedMaster~=nil and aw.ON~=savedMaster then aw.ON=savedMaster; changed=true end
        if type(aw.Buffs)=='table' and savedEnemyBuffs~=nil and aw.Buffs.ShowEnemy~=savedEnemyBuffs then
            aw.Buffs.ShowEnemy=savedEnemyBuffs; changed=true
        end
        if type(aw.Debuffs)=='table' and savedEnemyDebuffs~=nil and aw.Debuffs.ShowEnemy~=savedEnemyDebuffs then
            aw.Debuffs.ShowEnemy=savedEnemyDebuffs; changed=true
        end
        savedMaster,savedEnemyBuffs,savedEnemyDebuffs=nil,nil,nil
        if changed then refreshTP(a) end
        return false
    end

    remember(aw)

    if tpOwnsNameplates() then
        -- Threat Plates owns Nameplates: its exact Enemy Buff/Debuff switches ON.
        -- GODMODE does nothing else to Threat Plates.
        -- Preserve Threat Plates' user-selected aura visibility. Cooldowns Only
        -- changes Duration/Stack Count/ShowOmniCC only.
        -- A prior GODMODE-owned session may have turned the enemy aura
        -- switches OFF. Releasing ownership must re-enable the provider's
        -- existing aura widget, otherwise its icons disappear above NPCs.
        -- Refresh only when a value actually changes; no frame scans or loops.
        local changed = setEnemySwitches(aw, true)
        if changed then refreshTP(a, true) end
        return false
    end

    -- GODMODE owns Nameplates: exact Enemy Buff/Debuff switches OFF only.
    -- No frame hiding, Active flags, widget-manager disabling, or frame hooks.
    setEnemySwitches(aw,false)
    refreshTP(a)
    return true
end

function Bridge:OwnsCooldown(cooldown)
    -- Threat Plates creates this distinctive SetShownSwipe method on its own
    -- aura cooldown frames.  No ancestry walks or per-frame scanning.
    if _G.OmniCC_GODMODE_CooldownsOnly ~= true or not cooldown then return false end
    if cooldown._ogmTPAuraCooldown then return true end
    -- Threat Plates' CreateCooldown lives in its PRIVATE Addon namespace,
    -- not TidyPlatesThreat.CreateCooldown. The old factory hook never ran.
    -- Identify the real aura button from its native TimeLeft/Stacks regions.
    local ok, parent = pcall(cooldown.GetParent, cooldown)
    if not ok or not parent then return false end
    local isAura, yes = pcall(function()
        return parent.Cooldown == cooldown and parent.Icon ~= nil
            and (parent.Stacks ~= nil or parent.TimeLeft ~= nil or parent.TimeText ~= nil)
    end)
    if not isAura or not yes then return false end
    cooldown._ogmTPAuraCooldown = true
    return true
end

-- No temporary Threat Plates duration overrides are made.
function Bridge:RestoreOriginalTPSettings()
    return
end

function Bridge:Refresh()
    return self:ApplyOwnership()
end

-- Threat Plates' cooldown factory is private; identify aura cooldowns through
-- their actual parent widgets in OwnsCooldown instead of patching a nonexistent
-- public factory. No native countdown ownership is enabled here.
local function installTPFactoryBridge() end

-- Startup must not modify Threat Plates' manual aura-text settings.
local f = CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('ADDON_LOADED')
f:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' and name ~= 'TidyPlates_ThreatPlates' then return end
    installTPFactoryBridge()
    Bridge:ApplyOwnership()
end)
