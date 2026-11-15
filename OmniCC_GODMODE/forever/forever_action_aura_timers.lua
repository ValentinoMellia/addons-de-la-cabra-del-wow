-- Forever action-button target debuff durations. Independent from cooldown styling.
local _, Addon = ...
local M = CreateFrame('Frame')
Addon.ForeverActionAuraTimers = M
local db, overlays = nil, {}
local function database()
    OmniCC_GODMODE_ForeverActionAuraTimersDB = OmniCC_GODMODE_ForeverActionAuraTimersDB or {}
    db = OmniCC_GODMODE_ForeverActionAuraTimersDB
    if db.enabled == nil then db.enabled = true end
    return db
end
local prefixes={'ActionButton','MultiBarBottomLeftButton','MultiBarBottomRightButton','MultiBarRightButton','MultiBarLeftButton','MultiBar5Button','MultiBar6Button','MultiBar7Button'}
local function spellFor(button)
    local action=button.action
    if not action and button.CalculateAction then
        local ok,v=pcall(button.CalculateAction,button); if ok then action=v end
    end
    if type(action)~='number' or action<=0 then return nil end
    local kind,id=GetActionInfo(action)
    if kind=='spell' then return id end
    if kind=='macro' and GetMacroSpell then return GetMacroSpell(id) end
end
-- Forever builds may not expose the legacy UnitDebuff global. Read the
-- supported aura API without invoking missing functions on every OnUpdate.
local function readTargetDebuff(index)
    if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == 'function' then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, 'target', index, 'HARMFUL')
        if ok then
            if not aura then return nil end
            return aura.spellId, aura.duration, aura.expirationTime, aura.sourceUnit, true
        end
    end
    local reader = type(UnitDebuff) == 'function' and UnitDebuff
        or (type(UnitAura) == 'function' and UnitAura)
    if not reader then return nil end
    local ok, name, _, _, _, duration, expiration, source, _, _, id
    if reader == UnitDebuff then
        ok, name, _, _, _, duration, expiration, source, _, _, id = pcall(reader, 'target', index)
    else
        ok, name, _, _, _, duration, expiration, source, _, _, id = pcall(reader, 'target', index, 'HARMFUL')
    end
    if not ok or not name then return nil end
    return id, duration, expiration, source, true
end
local function targetDurations()
    local out = {}
    if not UnitExists('target') then return out end
    for i = 1, 40 do
        local id, duration, expiration, source, found = readTargetDebuff(i)
        if not found then break end
        if id and (source == 'player' or source == 'pet')
            and type(expiration) == 'number' and type(duration) == 'number' and duration > 0 then
            out[id] = expiration - GetTime()
        end
    end
    return out
end
local function formatTime(t)
    if t>=60 then return string.format('%dm',math.ceil(t/60)) end
    if t>=10 then return tostring(math.ceil(t)) end
    return string.format('%.1f',math.max(0,t))
end
local function hideAll()
    for _,label in pairs(overlays) do label:Hide() end
end
local elapsed=0
M:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt
    if elapsed<0.2 then return end
    elapsed=0
    if not database().enabled then hideAll(); return end
    local durations=targetDurations()
    for _,prefix in ipairs(prefixes) do
        for i=1,12 do
            local button=_G[prefix..i]
            if button then
                local label=overlays[button]
                local remaining=durations[spellFor(button)]
                if remaining and remaining>0 then
                    if not label then
                        label=button:CreateFontString(nil,'OVERLAY','NumberFontNormal')
                        label:SetPoint('BOTTOM',button,'BOTTOM',0,2)
                        label:SetDrawLayer('OVERLAY',7)
                        overlays[button]=label
                    end
                    label:SetText(formatTime(remaining))
                    label:Show()
                elseif label then label:Hide() end
            end
        end
    end
end)
function M:GetOption(key) return database()[key] end
function M:SetOption(key,value)
    database()[key]=value and true or false
    if key=='enabled' and not value then hideAll() end
end
function M:Refresh() if not database().enabled then hideAll() end end
database()
