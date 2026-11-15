local TOTEM_GODMODE_FOREVER = false
-- GODMODE totem nameplate identifier. Event-driven; does not alter aura/cooldown engines.
local addonName = ...
local isForever = (select(4, GetBuildInfo()) == 16001)
if (TOTEM_GODMODE_FOREVER and not isForever) or (not TOTEM_GODMODE_FOREVER and isForever) then return end

local names = {}
local entries = {
    {3599, "Searing Totem"}, {8071, "Stoneskin Totem"},
    {5730, "Stoneclaw Totem"}, {8071, "Stoneskin Totem"},
    {8075, "Strength of Earth Totem"}, {5394, "Healing Stream Totem"},
    {5675, "Mana Spring Totem"}, {8181, "Frost Resistance Totem"},
    {8184, "Fire Resistance Totem"}, {10595, "Nature Resistance Totem"},
    {8227, "Flametongue Totem"}, {8512, "Windfury Totem"},
    {2484, "Earthbind Totem"}, {8143, "Tremor Totem"},
    {8177, "Grounding Totem"}, {8190, "Magma Totem"},
    {1535, "Fire Nova Totem"}, {16190, "Mana Tide Totem"},
    {6495, "Sentry Totem"}, {3738, "Wrath of Air Totem"},
    {30706, "Totem of Wrath"}, {2062, "Earth Elemental Totem"},
    {2894, "Fire Elemental Totem"}, {108270, "Stone Bulwark Totem"},
    {192058, "Capacitor Totem"}, {98008, "Spirit Link Totem"},
    {198838, "Earthen Wall Totem"}, {204331, "Counterstrike Totem"},
    {51485, "Earthgrab Totem"}, {192077, "Wind Rush Totem"},
    {204336, "Grounding Totem"}, {207399, "Ancestral Protection Totem"},
    {108280, "Healing Tide Totem"}, {157153, "Cloudburst Totem"},
}
local function register(name, spell)
    if type(name) ~= "string" or name == "" then return end
    names[name] = spell
end
for i = 1, #entries do
    local spell, fallback = entries[i][1], entries[i][2]
    register(fallback, spell)
    local localized
    if C_Spell and C_Spell.GetSpellName then
        local ok, result = pcall(C_Spell.GetSpellName, spell)
        if ok then localized = result end
    elseif GetSpellInfo then
        local ok, result = pcall(GetSpellInfo, spell)
        if ok then localized = result end
    end
    register(localized, spell)
end

-- Match ranked totems (e.g. "Searing Totem II") without mistaking other units.
-- Exact names are preferred; suffixes are limited to standard rank notation.
local romanRanks = { I=true, II=true, III=true, IV=true, V=true, VI=true,
    VII=true, VIII=true, IX=true, X=true, XI=true, XII=true }
local function resolveTotem(name)
    if type(name) ~= "string" then return end
    local exact = names[name]
    if exact then return exact end
    local base, suffix = name:match("^(.-)%s+([IVX]+)$")
    if base and romanRanks[suffix] then return names[base] end
    local numberedBase, number = name:match("^(.-)%s+[Rr]ank%s+(%d+)$")
    if numberedBase and tonumber(number) and tonumber(number) <= 20 then
        return names[numberedBase]
    end
end

-- Independent per-profile module switches; default preserves working icons.
local function moduleProfile()
    local root = _G.OmniCC_GODMODE
    return root and root.db and root.db.profile
end
local function moduleOption(key)
    local profile = moduleProfile()
    return not profile or type(profile._ogmTotems) ~= 'table' or profile._ogmTotems[key] ~= false
end
local function setModuleOption(key, enabled)
    local profile = moduleProfile()
    if not profile then return false end
    if type(profile._ogmTotems) ~= 'table' then profile._ogmTotems = {} end
    profile._ogmTotems[key] = enabled and true or false
    return true
end
local refreshModule
_G.OmniCC_GODMODE_TotemIconsAPI = {
    GetEnabled = function() return moduleOption('icons') end,
    SetEnabled = function(_, v) if setModuleOption('icons', v) and refreshModule then refreshModule() end end,
}
local plates = setmetatable({}, {__mode="k"})
local units = {}
local pending = {}
local retries = {}
local seen = {}
local function textureFor(spell)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
        if ok then return tex end
    end
    if GetSpellTexture then
        local ok, tex = pcall(GetSpellTexture, spell)
        if ok then return tex end
    end
end
local function onAdded(unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return false end
    local name = UnitName(unit)
    if type(issecretvalue) == "function" and issecretvalue(name) then return false end
    if type(name) ~= "string" or name == "" then return false end
    if not moduleOption("icons") then
        local existing = plates[plate]
        if existing then existing.holder:Hide() end
        units[unit] = nil
        return true
    end
    local spell = resolveTotem(name)
    local state = plates[plate]
    if not spell then
        if state then state.holder:Hide(); state.unit = nil end
        units[unit] = nil
        return true
    end
    local texture = textureFor(spell)
    if not texture then return false end
    if not state then
        local holder = CreateFrame("Frame", nil, plate)
        holder:SetSize(23, 23)
        holder:SetPoint("BOTTOM", plate, "TOP", 0, 7)
        local icon = holder:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints(holder)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local timer = holder:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        timer:SetPoint('CENTER', holder, 'CENTER', 0, 0)
        state = {holder=holder, icon=holder, texture=icon, timer=timer}
        plates[plate] = state
    end
    state.unit = unit
    units[unit] = plate
    state.texture:SetTexture(texture)
    state.holder:Show()
    -- Duration is only displayed if a real aura expiration is exposed.
    -- A nameplate appearing does not reveal the summon time.
    if state.timer then state.timer:SetText('') end
    return true
end
refreshModule = function()
    if not moduleOption('icons') then
        for unit in pairs(seen) do seen[unit] = (seen[unit] or 0) + 1 end
        for _, state in pairs(plates) do state.holder:Hide() end
        return
    end
    for unit in pairs(units) do onAdded(unit) end
end
local function onRemoved(unit)
    if type(unit) ~= "string" then return end
    local plate = units[unit]
    units[unit] = nil
    pending[unit] = nil
    retries[unit] = nil
    if not plate and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        plate = C_NamePlate.GetNamePlateForUnit(unit)
    end
    if plate then
        local state = plates[plate]
        if state and state.unit == unit then
            state.unit = nil
            state.holder:Hide()
        end
    end
end
-- Retry only briefly after a nameplate is first created.  Never poll all units.
-- The generation token prevents callbacks from reviving removed/recycled plates.
local function scheduleAdded(unit)
    if not moduleOption("icons") then return end
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local generation = (seen[unit] or 0) + 1
    seen[unit] = generation
    retries[unit] = 0
    local function attempt()
        if seen[unit] ~= generation or not moduleOption("icons") then return end
        if onAdded(unit) then return end
        local count = (retries[unit] or 0) + 1
        retries[unit] = count
        if count < 4 and C_Timer and C_Timer.After then
            C_Timer.After(0.15, attempt)
        end
    end
    attempt()
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        seen[unit] = (seen[unit] or 0) + 1
        onRemoved(unit)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if moduleOption("icons") then scheduleAdded(unit) end
    elseif event == "UNIT_NAME_UPDATE" and moduleOption("icons") and type(unit) == "string"
        and unit:match("^nameplate%d+$") then
        onAdded(unit)
    end
end)

-- Enable dedicated totem nameplates automatically on Forever, as done by
-- Totem Nameplates. Never force general friendly/player nameplates on.
-- A separate disable command suppresses automatic re-enabling for this session.
local automaticTotems = true
local function activateTotems()
    if not isForever or not automaticTotems or not moduleOption("icons") then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for _, cvar in ipairs({"nameplateShowEnemyTotems", "nameplateShowFriendlyPlayerTotems"}) do
        local ok, current = pcall(GetCVar, cvar)
        if ok and current ~= nil and current ~= "" and current ~= "1" then
            if C_CVar and C_CVar.SetCVar then
                pcall(C_CVar.SetCVar, cvar, "1")
            elseif SetCVar then
                pcall(SetCVar, cvar, "1")
            end
        end
    end
end
local activation = CreateFrame("Frame")
activation:RegisterEvent("PLAYER_LOGIN")
activation:RegisterEvent("PLAYER_ENTERING_WORLD")
activation:SetScript("OnEvent", function()
    activateTotems()
end)

-- Explicit opt-in: enabling dedicated totem nameplates changes Blizzard CVars.
-- Do not silently override user preferences at login or in combat.
local function setTotemPlates(enabled)
    if InCombatLockdown and InCombatLockdown() then
        print("GODMODE Totems: Change totem nameplates outside combat.")
        return
    end
    local value = enabled and "1" or "0"
    local cvars = {"nameplateShowEnemyTotems", "nameplateShowFriendlyPlayerTotems"}
    for i = 1, #cvars do
        local name = cvars[i]
        local current = GetCVar and GetCVar(name)
        if current ~= nil and current ~= "" then
            if C_CVar and C_CVar.SetCVar then
                pcall(C_CVar.SetCVar, name, value)
            elseif SetCVar then
                pcall(SetCVar, name, value)
            end
            print("GODMODE Totems: " .. name .. " = " .. tostring(GetCVar(name)))
        else
            print("GODMODE Totems: " .. name .. " not exposed by this client.")
        end
    end
end

-- Diagnostics use the unit API rather than depending on namePlateUnitToken,
-- which is absent on some plate implementations. This runs only on demand.
local function diagnose()
    local count, totems = 0, 0
    local active = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    local visited = {}
    for i = 1, #active do
        local plate = active[i]
        local unit = plate and plate.namePlateUnitToken
        if type(unit) == "string" then visited[unit] = true end
    end
    -- Bounded, diagnostic-only token lookup. No polling or per-frame work.
    for i = 1, 80 do
        local unit = "nameplate" .. i
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then visited[unit] = true end
    end
    for unit in pairs(visited) do
        count = count + 1
        local name = UnitName(unit)
        if (type(issecretvalue) ~= "function" or not issecretvalue(name)) and type(name) == "string" then
            if resolveTotem(name) then
                totems = totems + 1
                print("GODMODE Totems: " .. unit .. " = " .. name)
                onAdded(unit)
            end
        end
    end
    print("GODMODE Totems: " .. count .. " exposed nameplates; " .. totems .. " recognized totems.")
    print("GODMODE Totems CVars: enemy=" .. tostring(GetCVar("nameplateShowEnemyTotems")) ..
        " friendly=" .. tostring(GetCVar("nameplateShowFriendlyPlayerTotems")))
    if totems == 0 then
        print("GODMODE Totems: Try /ogmtotems enable outside combat, then summon a totem. Dungeon friendly plates may be restricted by the client.")
    end
end
SLASH_OGMTOTEMS1 = "/ogmtotems"
SlashCmdList.OGMTOTEMS = function(arg)
    arg = type(arg) == "string" and arg:lower():match("^%s*(.-)%s*$") or ""
    if arg == "enable" or arg == "on" then
        automaticTotems = true
        setTotemPlates(true)
    elseif arg == "disable" or arg == "off" then
        automaticTotems = false
        setTotemPlates(false)
    else
        diagnose()
    end
end
