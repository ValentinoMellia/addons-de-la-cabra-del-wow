-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface == 16001 then return end
local _, Addon = ...

-- Midnight Action Button Aura Timers
-- Shows the live TARGET debuff duration on the spell's action button (Sunfire,
-- Moonfire, Flame Shock, etc.) using Blizzard's secure AuraContainer duration
-- binding. No protected remaining-time values are read by addon Lua.
local Module = CreateFrame('Frame')
Addon.MidnightActionAuraTimers = Module
_G.OmniCC_GODMODE_ActionAuraTimers = Module

local defaults = { enabled = true }
local db
local records = {}
local rebuildQueued = false
local groupSerial = 0

-- Some Midnight spells use a different aura spellID from the action/spellbook ID.
-- AuraContainer filters by the aura's ID, so include the known aura aliases too.
-- Druid: Moonfire 8921 -> aura 164812; Sunfire 93402 -> aura 164815.
local auraAliases = {
    [8921]  = {164812}, -- Moonfire
    [164812]= {8921},
    [93402] = {164815}, -- Sunfire
    [164815]= {93402},
}

local function EnsureDB()
    OmniCC_GODMODE_MidnightActionAuraTimersDB = OmniCC_GODMODE_MidnightActionAuraTimersDB or {}
    db = OmniCC_GODMODE_MidnightActionAuraTimersDB
    for k,v in pairs(defaults) do if db[k] == nil then db[k] = v end end
end

local function IsHarmful(spellID)
    if C_Spell and C_Spell.IsSpellDataCached and C_Spell.RequestLoadSpellData then
        local ok,cached=pcall(C_Spell.IsSpellDataCached,spellID)
        if ok and not cached then pcall(C_Spell.RequestLoadSpellData,spellID) end
    end
    if C_Spell and C_Spell.IsSpellHarmful then
        local ok,v=pcall(C_Spell.IsSpellHarmful,spellID); if ok then return v == true end
    end
    if IsHarmfulSpell then local ok,v=pcall(IsHarmfulSpell,spellID); if ok then return v == true end end
    return true
end

local function GetSpellID(button)
    if not button then return nil end
    -- Blizzard action buttons can expose a slot through action or CalculateAction.
    local slot = button.action
    if not slot and button.CalculateAction then
        local ok, value = pcall(button.CalculateAction, button)
        if ok then slot = value end
    end
    if type(slot) ~= 'number' or slot <= 0 then return nil end
    local ok, actionType, actionID = pcall(GetActionInfo, slot)
    if not ok then return nil end
    if actionType == 'spell' and type(actionID) == 'number' then return actionID end
    if actionType == 'macro' and type(actionID) == 'number' and GetMacroSpell then
        local good, spell = pcall(GetMacroSpell, actionID)
        if good and type(spell) == 'number' then return spell end
    end
    if C_ActionBar and C_ActionBar.GetSpellID then
        local good, spell = pcall(C_ActionBar.GetSpellID, slot)
        if good and type(spell) == 'number' and spell > 0 then return spell end
    end
    return nil
end

local function GetButtons()
    local out,seen={},{}
    local prefixes={'ActionButton','MultiBarBottomLeftButton','MultiBarBottomRightButton','MultiBarRightButton','MultiBarLeftButton','MultiBar5Button','MultiBar6Button','MultiBar7Button'}
    for _,prefix in ipairs(prefixes) do
        for i=1,12 do
            local b=_G[prefix..i]
            if b and not seen[b] then seen[b]=true; out[#out+1]=b end
        end
    end
    return out
end

local function ClearRecord(button)
    local r=records[button]
    if not r then return end
    if r.container then
        if r.container.SetEnabled then pcall(r.container.SetEnabled,r.container,false) end
        r.container:Hide()
    end
    if r.slot then r.slot:Hide() end
    if r.visibility then
        if UnregisterStateDriver then UnregisterStateDriver(r.visibility,'visibility') end
        r.visibility:Hide()
    end
    records[button]=nil
end

local function ClearAll()
    for b in pairs(records) do ClearRecord(b) end
end

local function Make(button,spellID)
    if not IsHarmful(spellID) then return end
    -- ActionBarAuras uses Aura SLOTS (not AddAuraGroup): a slot's secure
    -- AuraButton owns the duration text and can be overlaid on an action button.
    -- Keep this container strictly on the action button; never create nameplate auras.
    -- Visibility is controlled by Blizzard's secure state driver, not by
    -- addon calls to protected AuraSlot:SetAlpha/Hide during combat.
    -- The wrapper is created once, outside combat, for this action button.
    local visibility=CreateFrame('Frame',nil,button,'SecureHandlerStateTemplate')
    visibility:SetAllPoints(button)
    local c=CreateFrame('AuraContainer',nil,visibility,'CustomAuraContainerTemplate')
    c:SetUnit('target')
    c:SetEnabled(false)
    local map={[spellID]=true}
    local aliases=auraAliases[spellID]
    if aliases then for i=1,#aliases do map[aliases[i]]=true end end
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok,overrideID=pcall(C_Spell.GetOverrideSpell,spellID)
        if ok and type(overrideID)=='number' and overrideID>0 then map[overrideID]=true end
    end
    local auraFrame
    local slot=c:AddAuraSlot('OGMAction', '', {
        sortMethod=AuraContainerSortMethod.ExpirationOnly,
        sortDirection=AuraContainerSortDirection.Reverse,
        templateNames={'OGMActionAuraOverlayTemplate'},
        initializeFrame=function(frame)
            auraFrame=frame
            frame:EnableMouse(false)
            local txt=frame.durationText
            if txt then
                txt:ClearAllPoints()
                txt:SetPoint('BOTTOM',frame,'BOTTOM',0,2)
                txt:SetDrawLayer('OVERLAY',7)
                local binder=Addon.GODMODEDurationBinding
                if binder and binder.Bind then
                    binder:Bind(frame,txt,{themeID='default',actionBarColors=true})
                elseif frame.SetDurationText then
                    pcall(frame.SetDurationText,frame,txt)
                end
            end
        end,
    })
    if not slot then c:Hide(); return end
    c:ClearAllPoints()
    c:SetPoint('TOPLEFT',button,'TOPLEFT')
    c:SetSize(button:GetSize())
    slot:ClearAllPoints()
    slot:SetPoint('CENTER',button,'CENTER')
    slot:SetSize(button:GetSize())
    if button.cooldown then slot:SetFrameLevel(button.cooldown:GetFrameLevel()+1) end
    c:SetAuraSlotFilterString('OGMAction','HARMFUL|PLAYER')
    c:SetAuraSlotCandidateFilters('OGMAction',{isHarmful=true,includeSpellIDs=map})
    c:SetEnabled(true)
    c:Show()
    -- Securely hide the whole overlay when there is no living target.
    -- Blizzard's native harmful/player aura slot filter controls whether
    -- an actual matching debuff exists on a living target.
    RegisterStateDriver(visibility,'visibility','[@target,exists,nodead] show; hide')
    records[button]={container=c,slot=slot,spellID=spellID,visibility=visibility}

end

-- Blizzard owns the secure duration and visibility for each filtered AuraSlot.
-- Never force the container visible based solely on UnitExists: that revives
-- a previous target's timer even when the new target lacks the debuff.
-- The target token stays dynamic, and UNIT_AURA is handled by Blizzard.
local function RefreshTargetVisibility()
    -- Intentionally no manual Show/SetAlpha on the secure aura provider.
end

local function Rebuild()
    rebuildQueued=false; EnsureDB()
    if InCombatLockdown and InCombatLockdown() then rebuildQueued=true; return end
    if db.enabled == false or not CreateFrame then ClearAll(); return end
    local active = {}
    for _,button in ipairs(GetButtons()) do
        local id=GetSpellID(button)
        if id and IsHarmful(id) then
            active[button]=true
            if not records[button] or records[button].spellID ~= id then
                ClearRecord(button)
                pcall(Make,button,id)
            end
        end
    end
    for button in pairs(records) do
        if not active[button] then ClearRecord(button) end
    end
    RefreshTargetVisibility()
end

local function QueueRebuild()
    if rebuildQueued then return end
    rebuildQueued=true
    C_Timer.After(.15,Rebuild)
end

function Module:GetOption(k) EnsureDB(); return db[k] end
function Module:SetOption(k,v)
    EnsureDB()
    local previous=db[k]
    db[k]=v
    if k=='enabled' then
        if v==false then
            -- OFF is immediate; no reload and no delayed rebuild.
            rebuildQueued=false
            ClearAll()
            return
        elseif previous~=true then
            -- The option is persisted before rebuilding.  Do not invoke ReloadUI
            -- from the checkbox click: the Modules panel must reflect ON now.
            -- Queue a fresh secure aura-container build outside combat.
            if InCombatLockdown and InCombatLockdown() then
                rebuildQueued=true
                return
            end
            QueueRebuild()
            return
        end
    end
    QueueRebuild()
end
function Module:Refresh() QueueRebuild() end

Module:RegisterEvent('PLAYER_LOGIN')
Module:RegisterEvent('PLAYER_ENTERING_WORLD')
Module:RegisterEvent('PLAYER_REGEN_ENABLED')
Module:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
Module:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
Module:RegisterEvent('UPDATE_BONUS_ACTIONBAR')
Module:RegisterEvent('SPELLS_CHANGED')
Module:RegisterEvent('PLAYER_TARGET_CHANGED')
Module:RegisterEvent('UNIT_HEALTH')
Module:RegisterEvent('UNIT_FLAGS')
Module:RegisterEvent('UNIT_AURA')
Module:SetScript('OnEvent',function(_,event,unit)
    if event=='PLAYER_TARGET_CHANGED' then
        RefreshTargetVisibility()
        return
    end
    if (event=='UNIT_HEALTH' or event=='UNIT_FLAGS' or event=='UNIT_AURA') and unit=='target' then
        RefreshTargetVisibility()
        return
    end
    if event=='PLAYER_REGEN_ENABLED' then
        if rebuildQueued then
            rebuildQueued=false
            QueueRebuild()
        end
        RefreshTargetVisibility()
        return
    end
    QueueRebuild()
end)
EnsureDB()
