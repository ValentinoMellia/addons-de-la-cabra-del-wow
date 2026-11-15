-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
if _G.OmniCC_GODMODE_CooldownsOnly == true then return end
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
-- Forever 70170+: do not gate on WOW_PROJECT_ID; the Camelot TOC + interface 16001 are authoritative.
local AddonName, Addon = ...

-- Optional GODMODE nameplate diagnostics. OFF by default, no timers or polling.
-- /ogmnpdiag on | off | report | reset
local OGM_NP_DIAG = _G.OGM_NameplateDiagnostics
if not OGM_NP_DIAG then
    OGM_NP_DIAG = {enabled=false, stats={}}
    _G.OGM_NameplateDiagnostics = OGM_NP_DIAG
    local function say(s)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage('|cffffcc00GODMODE NP:|r '..s)
        end
    end
    SLASH_OGMNPD1='/ogmnpdiag'
    SlashCmdList.OGMNPD=function(msg)
        msg=(msg or ''):lower():match('^%s*(.-)%s*$')
        if msg=='on' then OGM_NP_DIAG.enabled=true; say('Profiling ON (may add overhead). Rotate camera, then /ogmnpdiag report')
        elseif msg=='off' then OGM_NP_DIAG.enabled=false; say('Profiling OFF')
        elseif msg=='reset' then OGM_NP_DIAG.stats={}; say('Counters reset')
        else
            say('Profiling '..(OGM_NP_DIAG.enabled and 'ON' or 'OFF')..'; totals in milliseconds:')
            local entries={}
            for k,v in pairs(OGM_NP_DIAG.stats) do entries[#entries+1]={k,v} end
            table.sort(entries,function(a,b) return a[2].total>b[2].total end)
            for i=1,math.min(#entries,16) do
                local k,v=entries[i][1],entries[i][2]
                say(string.format('%s: %d calls, %.2f ms total, %.3f ms max, %.3f ms avg',k,v.count,v.total,v.max,v.total/math.max(1,v.count)))
            end
        end
    end
end
local function OGM_NP_Measure(key,fn,...)
    if not OGM_NP_DIAG.enabled or type(debugprofilestop)~='function' then return fn(...) end
    local start=debugprofilestop()
    -- Preserve every return value, including nils; propagate errors normally.
    local result={pcall(fn,...)}
    local elapsed=debugprofilestop()-start
    local stat=OGM_NP_DIAG.stats[key]
    if not stat then stat={count=0,total=0,max=0}; OGM_NP_DIAG.stats[key]=stat end
    stat.count=stat.count+1; stat.total=stat.total+elapsed
    if elapsed>stat.max then stat.max=elapsed end
    if not result[1] then error(result[2],0) end
    return unpack(result,2,#result)
end


-- Forever: style and reposition Blizzard's own nameplate aura container.
-- Blizzard remains responsible for aura detection, cooldowns and removal.

local DB_NAME = "OmniCC_GODMODE_ForeverNameplatesDB"

-- Forever 1.60.1 persistence note:
-- the embedded Forever engine uses AceDB-3.0 r1414/minor 36, matching the
-- working Threat Plates build.  That AceDB release has explicit Forever
-- realm/profile-key handling for interface 16001.  Older AceDB minor 33 did
-- not, which could make the active profile key differ across reloads.
local defaults = {
    enabled = true,
    auraScale = 1.10,
    quickSizeLevel = 6,
    -- NPC/nameplate countdown font size is independent from icon scale.
    -- Existing users migrate from the old Nameplates theme value on first load.
    countdownTextSize = 15,
    -- v35: dungeon readability toggle. Normal debuffs can be limited to the
    -- local player while CC remains visible from everyone.
    showAllDebuffs = true,
    -- 1.3.2: optional clean-nameplate mode. When enabled, only the current
    -- target owns a GODMODE debuff/CC row; non-target nameplates stay clean.
    targetOnly = true,
    ccPlacement = 'RIGHT', -- RIGHT = dedicated CC lane; TOP = together with normal NPC auras
    ccRightSize = 30, -- independent RIGHT-side CC square (native base is 30px)
    -- 1.3.6: friendly-player nameplate auras (restored). Separate saved toggles.
    friendlyHots = true,
    friendlyBuffs = true,
    friendlyDebuffs = true,
    -- Forever release default: keep NPC debuffs centered just above the
    -- health bar, matching the tested v33 in-game placement.  This only
    -- changes the fallback/reset position; live Move NPC behavior is unchanged.
    offsetX = 0,
    offsetY = 10,
    anchorShown = false,
    quickPoint = "CENTER",
    quickX = 0,
    quickY = 0,
    revision = 0,
    schema = 9,

    -- Smart Aura System 1.2.0
    filterPreset = 'ALL',
    priorityScaling = true,
    largeIconSize = 40,
    mediumIconSize = 30,
    smallIconSize = 22,
    showStuns = true, showFears = true, showRoots = true, showSlows = true, showSilences = true,
    showIncapacitates = true, showDisarms = true, showTaunts = false,
    showInterrupts = true, showDefensives = true, showImmunities = true,
    showDamageReduction = true, showAbsorptionShields = true, showOffensives = true,
    showHealingReduction = true, showDots = false, showBleeds = false,
    showPoisons = false, showDiseases = false, showCurses = false, showMagic = false,
    showBossMechanics = true, showRaidMechanics = true,
    customSourceMine = true, customSourceGroup = true, customSourceOthers = false,
    glowCC = true, glowInterrupts = true, glowImmunities = true,
    hideInsignificantInRaids = true,
}

-- Forever persistence uses independent scalar SavedVariables as the source of truth.
-- AceDB/profile tables may be recreated or replaced; scalar globals cannot be
-- silently replaced by another module.
local SCALAR = {
    enabled = "OmniCC_GODMODE_ForeverNPEnabled",
    auraScale = "OmniCC_GODMODE_ForeverNPScale",
    quickSizeLevel = "OmniCC_GODMODE_ForeverNPQuickSizeLevel",
    countdownTextSize = "OmniCC_GODMODE_ForeverNPCountdownTextSize",
    offsetX = "OmniCC_GODMODE_ForeverNPX",
    offsetY = "OmniCC_GODMODE_ForeverNPY",
    showAllDebuffs = "OmniCC_GODMODE_ForeverNPShowAllDebuffs",
    targetOnly = "OmniCC_GODMODE_ForeverNPTargetOnly",
    ccPlacement = "OmniCC_GODMODE_ForeverNPCCPlacement",
    ccRightSize = "OmniCC_GODMODE_ForeverNPCCRightSize",
    friendlyHots = "OmniCC_GODMODE_ForeverNPFriendlyHots",
    friendlyBuffs = "OmniCC_GODMODE_ForeverNPFriendlyBuffs",
    friendlyDebuffs = "OmniCC_GODMODE_ForeverNPFriendlyDebuffs",

    quickPoint = "OmniCC_GODMODE_ForeverNPQuickPoint",
    quickX = "OmniCC_GODMODE_ForeverNPQuickX",
    quickY = "OmniCC_GODMODE_ForeverNPQuickY",
}

local function loadScalars(target)
    for key, globalName in pairs(SCALAR) do
        local value = rawget(_G, globalName)
        if value ~= nil then target[key] = value end
    end
end

local function saveScalars(source)
    for key, globalName in pairs(SCALAR) do
        rawset(_G, globalName, source[key])
    end
end

-- Use one dedicated SavedVariables table and never replace it after loading.
-- Older builds occasionally held a stale local table while another module wrote
-- to the global SavedVariables key. This helper keeps both references identical.
local function getPersistentDB()
    local saved = rawget(_G, DB_NAME)
    local hadExistingSavedDB = type(saved) == "table"
    if not hadExistingSavedDB then
        saved = {}
        rawset(_G, DB_NAME, saved)
    end

    -- Existing users may migrate their old theme value once. Brand-new installs
    -- must use the dedicated NPC default and must not import AceDB's theme default.
    if hadExistingSavedDB and saved.countdownTextSize == nil then
        local profile = Addon.db and Addon.db.profile
        local theme = profile and profile.themes and profile.themes[(profile.godmodeAutoFitEnabled and 'godmode_autofit') or 'nameplates']
        local oldSize = tonumber(theme and theme.fontSize)
        if oldSize then
            saved.countdownTextSize = math.max(6, math.min(48, math.floor(oldSize + 0.5)))
        end
    end

    for key, value in pairs(defaults) do
        if saved[key] == nil then saved[key] = value end
    end
    return saved
end

local db = {}

-- These runtime size locals must be declared before loadPersistentState().
-- Lua resolves locals lexically; declaring them later made the early loader
-- see QUICK_SCALE_BY_LEVEL/sessionQuickSizeLevel as globals.
local QUICK_SCALE_BY_LEVEL = {
    [1] = 0.60,
    [2] = 0.70,
    [3] = 0.80,
    [4] = 0.90,
    [5] = 1.00,
    [6] = 1.10,
    [7] = 1.20,
    [8] = 1.30,
    [9] = 1.40,
    [10] = 1.50,
}
local sessionQuickSizeLevel = 6 -- replaced by the saved value in loadPersistentState()

local pendingCombatRefresh = false

local function inCombatLockdown()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function isForbiddenObject(object)
    if not object then return true end
    if object.IsForbidden then
        local ok, forbidden = pcall(object.IsForbidden, object)
        if ok and forbidden then return true end
    end
    return false
end

local function isProtectedObject(object)
    if not object then return true end
    if object.IsProtected then
        local ok, protected = pcall(object.IsProtected, object)
        if ok and protected then return true end
    end
    return false
end

local function queueCombatRefresh()
    pendingCombatRefresh = true
end

local function canModifyObject(object)
    if not object or isForbiddenObject(object) then return false end

    if inCombatLockdown() and isProtectedObject(object) then
        queueCombatRefresh()
        return false
    end

    return true
end
-- anchorShown is session-only; position remains persistent.
for key, value in pairs(defaults) do
    if db[key] == nil then db[key] = value end
end
local persistenceReady = false

-- Keep two physical SavedVariables copies, but choose the newest one on load.
-- Older builds always trusted the dedicated table even when another module had
-- recreated it with defaults, which discarded the user's valid mirrored values.
local function getMirror(create)
    local root = rawget(_G, "OmniCC_GODMODE_ForeverDB")
    if type(root) ~= "table" then
        if not create then return nil end
        root = {}
        rawset(_G, "OmniCC_GODMODE_ForeverDB", root)
    end
    if type(root.global) ~= "table" then
        if not create then return nil end
        root.global = {}
    end
    if type(root.global.foreverNameplates) ~= "table" then
        if not create then return nil end
        root.global.foreverNameplates = {}
    end
    return root.global.foreverNameplates
end

local function tableRevision(t)
    return type(t) == "table" and tonumber(t.revision) or 0
end

local function getCharacterCopy(create)
    local copy = rawget(_G, "OmniCC_GODMODE_ForeverNameplatesCharDB")
    if type(copy) ~= "table" and create then
        copy = {}
        rawset(_G, "OmniCC_GODMODE_ForeverNameplatesCharDB", copy)
    end
    return type(copy) == "table" and copy or nil
end

local function persist(bumpRevision)
    if not persistenceReady then return end
    local saved = getPersistentDB()
    if saved ~= db then
        for key, value in pairs(db) do saved[key] = value end
        db = saved
    end

    if bumpRevision ~= false then
        db.revision = math.max(tableRevision(db), tableRevision(getMirror(false))) + 1
    else
        db.revision = tableRevision(db)
    end
    db.schema = defaults.schema

    local copy = getMirror(true)
    for key in pairs(defaults) do copy[key] = db[key] end
    copy.revision = db.revision
    copy.schema = defaults.schema

    local character = getCharacterCopy(true)
    for key in pairs(defaults) do character[key] = db[key] end
    character.revision = db.revision
    character.schema = defaults.schema

    -- Final authoritative write. These globals are declared directly in the
    -- TOC and survive reload independently of AceDB/profile tables.
    saveScalars(db)
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end


local function loadPersistentState()
    -- SavedVariables are guaranteed to be ready at ADDON_LOADED.
    local saved = getPersistentDB()
    local mirror = getMirror(false)
    local charCopy = getCharacterCopy(false)
    local newest = saved
    if mirror and tableRevision(mirror) > tableRevision(newest) then newest = mirror end
    if charCopy and tableRevision(charCopy) > tableRevision(newest) then newest = charCopy end

    for key, defaultValue in pairs(defaults) do
        local value = newest[key]
        if value == nil then value = defaultValue end
        saved[key] = value
    end

    loadScalars(saved)

    -- Forever v1.3.0 repair: a broken shared config panel could leave this nil
    -- or store an invalid value.  ALL is the safe/default ownership mode and
    -- guarantees the GODMODE renderer does not silently filter every aura.
    local validPresets = {IMPORTANT=true, ALL=true, CC=true, INTERRUPTS=true, DEFENSIVES=true, OFFENSIVES=true, PVP=true, ARENA=true, RAID=true, DUNGEON=true, CUSTOM=true}
    if not validPresets[saved.filterPreset] then saved.filterPreset = 'ALL' end

    -- Upgrade metadata only. Never reset an existing user's enabled state,
    -- size, position, filters, or other SavedVariables during an addon update.
    local loadedSchema = tonumber(newest.schema) or 0

    saved.auraScale = clamp(saved.auraScale, 0.60, 1.50)
    if loadedSchema < 7 then
        -- v1.2.3 kept quickSizeLevel and auraScale as separate size states.
        -- Preserve an existing valid 1..10 level first; only derive from the
        -- old continuous scale when no usable level was actually saved.
        local priorLevel = tonumber(saved.quickSizeLevel)
        if not priorLevel or priorLevel < 1 or priorLevel > 10 then
            local bestLevel, bestDistance = 5, math.huge
            for level = 1, 10 do
                local candidate = 0.50 + (level * 0.10)
                local distance = math.abs(saved.auraScale - candidate)
                if distance < bestDistance then bestLevel, bestDistance = level, distance end
            end
            saved.quickSizeLevel = bestLevel
        else
            saved.quickSizeLevel = math.floor(priorLevel + 0.5)
        end
    end
    -- Restore the user's actual saved quick-size state. 6/10 is only the
    -- fresh-install/reset default; it must never overwrite an existing choice.
    saved.quickSizeLevel = clamp(math.floor(tonumber(saved.quickSizeLevel) or 6), 1, 10)
    saved.auraScale = QUICK_SCALE_BY_LEVEL[saved.quickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
    rawset(_G, SCALAR.quickSizeLevel, saved.quickSizeLevel)
    rawset(_G, SCALAR.auraScale, saved.auraScale)
    -- v34: move only the untouched legacy default to the new release default.
    -- Never overwrite a real user-adjusted Move NPC position.
    if (tonumber(saved.schema) or 0) < 8
        and (tonumber(saved.offsetX) or 0) == 0
        and (tonumber(saved.offsetY) or 0) == 0 then
        saved.offsetX = defaults.offsetX
        saved.offsetY = defaults.offsetY
    end
    saved.schema = math.max(tonumber(saved.schema) or 0, defaults.schema)

    saved.offsetX = clamp(saved.offsetX, -1000, 1000)
    saved.offsetY = clamp(saved.offsetY, -500, 1000)
    saved.schema = defaults.schema
    db = saved
    sessionQuickSizeLevel = saved.quickSizeLevel
    persistenceReady = true
    persist(false)
end

local function safeNumber(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return nil end
    local ok, number = pcall(tonumber, value)
    if ok then return number end
end

local function isAuraContainer(frame)
    if not frame or frame == UIParent or frame == WorldFrame then return false end

    -- Plater's visible aura rows expose PlaterBuffList / NextAuraIcon.
    local okList, list = pcall(function() return frame.PlaterBuffList end)
    if okList and type(list) == "table" then return true end
    local okNext, nextIcon = pcall(function() return frame.NextAuraIcon end)
    if okNext and safeNumber(nextIcon) then return true end

    -- Blizzard nameplate aura containers.
    local okMax, maxItems = pcall(function() return frame.maxAuraItemsDisplayed end)
    if okMax and safeNumber(maxItems) then return true end

    local okLayout, layout = pcall(function() return frame.layoutFramesGoingRight end)
    local okStride, stride = pcall(function() return frame.stride end)
    if okLayout and okStride and layout ~= nil and safeNumber(stride) then return true end

    return false
end

local function findAuraContainer(root, depth)
    if not root or depth > 5 then return nil end
    if isAuraContainer(root) then return root end

    local known = {
        "BuffFrame", "DebuffFrame", "AuraFrame", "AurasFrame",
        "AuraContainer", "BuffContainer", "DebuffContainer",
    }
    for _, key in ipairs(known) do
        local ok, child = pcall(function() return root[key] end)
        if ok and child and isAuraContainer(child) then return child end
    end

    if not root.GetChildren then return nil end
    local ok, children = pcall(function() return { root:GetChildren() } end)
    if not ok then return nil end
    for _, child in ipairs(children) do
        local found = findAuraContainer(child, depth + 1)
        if found then return found end
    end
end


-- Smart Aura System ---------------------------------------------------------
local SpellData = Addon.ForeverSpellData or _G.OmniCC_GODMODE_ForeverSpellData
local auraCategoryBySpell = {}
local function AddCategory(category, ids) for _, id in ipairs(ids) do auraCategoryBySpell[id] = category end end
-- Local fallback keeps the module functional if a future client blocks the
-- shared data file for any reason. The shared Forever database is preferred.
AddCategory('STUN', {853,408,1833,5211,22570,20549,30283,46968,107570,119381})
AddCategory('FEAR', {5782,5484,8122,5246,1513,2094,6358})
AddCategory('ROOT', {339,1062,5195,5196,9852,9853,122,865,6131,10230,33395,64695,102359,116706})
AddCategory('SLOW', {8056,8058,10472,10473,25464,1715,7372,7373,25212,12323,12324,12325})
AddCategory('SILENCE', {15487,1330,47476,204490,31935,19647,78675})
AddCategory('INCAP', {118,28271,28272,61721,61780,6770,2070,20066,3355,710,115078,217832})
AddCategory('DISARM', {676,51722,233759})
AddCategory('TAUNT', {355,6795,62124,56222,116189,185245})
AddCategory('HEALREDUCE', {12294,8680,115804,54680,197214})
AddCategory('IMMUNITY', {642,45438,1022,1044,31224,19263,186265,196555,204018})
AddCategory('DAMAGE_REDUCTION', {498,871,22812,33206,30823,47585,61336,48792,55233,102342,108271,122278,115203})
AddCategory('ABSORPTION', {17,11426,48707,77535,207472,235450,47753})
AddCategory('DEFENSIVE', {5277,12975,31850,31821,108416,104773,6940,116849})
AddCategory('OFFENSIVE', {1719,31884,10060,12472,12042,16166,13750,3045,19574,79140,51271,152173,113858,113860,194223,106951,102543,102560,191427,198067,137639,152277,228260})
local interruptSpells = { [1766]=true,[6552]=true,[2139]=true,[19647]=true,[57994]=true,[47528]=true,[96231]=true,[106839]=true,[116705]=true,[183752]=true,[147362]=true,[351338]=true,[187707]=true,[78675]=true }
local presetSets = {
 IMPORTANT={STUN=true,FEAR=true,ROOT=true,SLOW=true,SILENCE=true,INCAP=true,DISARM=true,INTERRUPT=true,IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true,OFFENSIVE=true,HEALREDUCE=true,BOSS=true,RAID=true},
 CC={STUN=true,FEAR=true,ROOT=true,SILENCE=true,INCAP=true,DISARM=true,SLOW=true}, INTERRUPTS={INTERRUPT=true},
 DEFENSIVES={IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true}, OFFENSIVES={OFFENSIVE=true},
 PVP={STUN=true,FEAR=true,ROOT=true,SILENCE=true,INCAP=true,DISARM=true,SLOW=true,INTERRUPT=true,IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true,OFFENSIVE=true,HEALREDUCE=true},
 ARENA={STUN=true,FEAR=true,ROOT=true,SILENCE=true,INCAP=true,DISARM=true,SLOW=true,INTERRUPT=true,IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true,OFFENSIVE=true,HEALREDUCE=true},
 RAID={INTERRUPT=true,STUN=true,SILENCE=true,IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true,HEALREDUCE=true,BOSS=true,RAID=true},
 DUNGEON={INTERRUPT=true,STUN=true,FEAR=true,ROOT=true,SILENCE=true,INCAP=true,SLOW=true,IMMUNITY=true,DEFENSIVE=true,DAMAGE_REDUCTION=true,ABSORPTION=true,BOSS=true,RAID=true},
}
local categoryOption={STUN='showStuns',SLOW='showSlows',FEAR='showFears',ROOT='showRoots',SILENCE='showSilences',INCAP='showIncapacitates',DISARM='showDisarms',TAUNT='showTaunts',INTERRUPT='showInterrupts',DEFENSIVE='showDefensives',IMMUNITY='showImmunities',DAMAGE_REDUCTION='showDamageReduction',ABSORPTION='showAbsorptionShields',OFFENSIVE='showOffensives',HEALREDUCE='showHealingReduction',DOT='showDots',BLEED='showBleeds',POISON='showPoisons',DISEASE='showDiseases',CURSE='showCurses',MAGIC='showMagic',BOSS='showBossMechanics',RAID='showRaidMechanics'}
local function readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function childAuraData(child)
    local data = {}
    local ok, aura = pcall(function() return child.auraData or child.data or child.AuraData end)
    if ok and type(aura)=='table' then
        local function pick(k) local o,v=pcall(function() return aura[k] end); if o and readable(v) then return v end end
        data.spellId=pick('spellId') or pick('spellID'); data.name=pick('name'); data.debuffType=pick('dispelName') or pick('debuffType'); data.source=pick('sourceUnit'); data.isBossAura=pick('isBossAura')
    end
    local function direct(k) local o,v=pcall(function() return child[k] end); if o and readable(v) then return v end end
    data.spellId=data.spellId or direct('spellId') or direct('spellID') or direct('auraSpellID')
    data.name=data.name or direct('spellName') or direct('name')
    data.debuffType=data.debuffType or direct('debuffType') or direct('dispelName')
    return data
end
local function auraCategory(data)
    if data.isBossAura then return 'BOSS' end
    local id=tonumber(data.spellId)
    if SpellData and SpellData.Category then
        local category=SpellData.Category(id,data.name)
        if category then return category end
        if SpellData.DamageCategory then
            local damage=SpellData.DamageCategory(id,data.name)
            if damage then return damage end
        end
    end
    if id and interruptSpells[id] then return 'INTERRUPT' end
    if id and auraCategoryBySpell[id] then return auraCategoryBySpell[id] end
    local t=data.debuffType; if t=='Poison' then return 'POISON' elseif t=='Disease' then return 'DISEASE' elseif t=='Curse' then return 'CURSE' elseif t=='Magic' then return 'MAGIC' end
    return 'DOT'
end
local function categoryAllowed(cat)
    local preset=db.filterPreset or 'ALL'; if preset=='ALL' then return true end
    if preset=='CUSTOM' then local k=categoryOption[cat]; return k and db[k] or false end
    local set=presetSets[preset] or presetSets.IMPORTANT; return set[cat] == true
end
-- 1.3.8 exact Custom NPC filter bridge --------------------------------------
-- The visible NPC row is a Blizzard CustomAuraContainer. Hiding generated
-- AuraButtons after Blizzard creates them is too late (and protected/secret on
-- Forever/Midnight). Custom therefore filters at the AuraContainer SOURCE via
-- includeSpellIDs. ALL keeps Blizzard's normal candidate set untouched.
local function buildCustomIncludeSpellIDs(ccOnly)
    if (db.filterPreset or 'ALL') ~= 'CUSTOM' then return nil, true end
    local include, any = {}, false
    local ccCats = {STUN=true,FEAR=true,ROOT=true,SLOW=true,SILENCE=true,INCAP=true,DISARM=true,INTERRUPT=true}
    local function addId(id, cat)
        local key = categoryOption[cat]
        if key and db[key] == true and (not ccOnly or ccCats[cat]) then
            id=tonumber(id)
            if id then include[id]=true; any=true end
        end
    end
    if SpellData then
        for id,cat in pairs(SpellData.byId or {}) do addId(id,cat) end
        for id,cat in pairs(SpellData.damageById or {}) do addId(id,cat) end
        for id in pairs(SpellData.interrupts or {}) do addId(id,'INTERRUPT') end
    end
    for id,cat in pairs(auraCategoryBySpell) do addId(id,cat) end
    for id in pairs(interruptSpells) do addId(id,'INTERRUPT') end
    return include, any
end
-- Camera hot-path cache: the CUSTOM spell candidate tables depend only on
-- GODMODE filter settings, not on the individual nameplate. Building them for
-- every NAME_PLATE_UNIT_ADDED walked the full spell database repeatedly while
-- turning the camera in crowded scenes. Cache one immutable pair per settings
-- signature; toggling a filter naturally changes the signature and rebuilds it.
-- Filter configuration is global and changes only when settings change.
-- Never cache live aura results: Blizzard owns per-unit UNIT_AURA updates.
local _ogmCandidateCache = {}
local _ogmCandidateKeys = {
    'showStuns','showSlows','showFears','showRoots','showSilences',
    'showIncapacitates','showDisarms','showTaunts','showInterrupts',
    'showDefensives','showImmunities','showDamageReduction','showAbsorptionShields',
    'showOffensives','showHealingReduction','showDots','showBleeds','showPoisons',
    'showDiseases','showCurses','showMagic','showBossMechanics','showRaidMechanics'
}
local _ogmCandidateSignature
local function invalidateCandidateConfiguration()
    _ogmCandidateSignature = nil
    _ogmCandidateCache = {}
end
local function candidateSignature()
    if _ogmCandidateSignature then return _ogmCandidateSignature end
    local out={tostring(db.filterPreset or 'ALL')}
    for i=1,#_ogmCandidateKeys do
        out[#out+1]=db[_ogmCandidateKeys[i]] and '1' or '0'
    end
    _ogmCandidateSignature=table.concat(out, ':')
    return _ogmCandidateSignature
end
local function getCachedCustomCandidates()
    local sig=candidateSignature()
    local hit=_ogmCandidateCache[sig]
    if hit then return hit[1],hit[2],hit[3],hit[4] end
    -- ALL/default presets use Blizzard's native filters. Do not walk the full
    -- custom spell database just to discard the resulting candidate lists.
    if (db.filterPreset or 'ALL') ~= 'CUSTOM' then
        _ogmCandidateCache={[sig]={false,true,false,true}}
        return false,true,false,true
    end
    local include,any=buildCustomIncludeSpellIDs(false)
    local ccInclude,ccAny=buildCustomIncludeSpellIDs(true)
    _ogmCandidateCache={[sig]={include,any,ccInclude,ccAny}}
    return include,any,ccInclude,ccAny
end

local function applyExactCustomCandidates(c)
    if not c then return false end
    local preset=db.filterPreset or 'ALL'
    local include, any, ccInclude, ccAny = getCachedCustomCandidates()
    -- Apply candidate filters only when their effective settings change.
    -- Repeating these secure setters on every camera/nameplate bind is costly.
    local signature = candidateSignature() .. ':' .. preset
    if c._ogmAppliedCandidateSignature ~= signature and c.SetAuraGroupCandidateFilters then
        if preset == 'CUSTOM' then
            local okH=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_harmful',{includeSpellIDs=include})
            local okCC=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_cc',{includeSpellIDs=ccInclude})
            if okH and okCC then c._ogmAppliedCandidateSignature=signature end
        else
            local okH=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_harmful',{})
            local okCC=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_cc',{})
            if okH and okCC then c._ogmAppliedCandidateSignature=signature end
        end
    end
    return preset ~= 'CUSTOM' or any, preset ~= 'CUSTOM' or ccAny
end
local function applyExactCustomLaneCandidates(c)
    if not c or not c.SetAuraGroupCandidateFilters then return true end
    local preset=db.filterPreset or 'ALL'
    local _, _, ccInclude, ccAny=getCachedCustomCandidates()
    -- Blizzard owns the live UNIT_AURA updates. Reapply the secure lane
    -- candidate filter only when the effective settings change, not on every
    -- nameplate bind, camera turn, or unchanged layout refresh.
    local signature=candidateSignature() .. ':' .. preset
    if c._ogmAppliedLaneCandidateSignature ~= signature then
        local ok
        if preset=='CUSTOM' then
            ok=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_lane_CC',{includeSpellIDs=ccInclude})
        else
            ok=pcall(c.SetAuraGroupCandidateFilters,c,'ogm_lane_CC',{})
        end
        if ok then c._ogmAppliedLaneCandidateSignature=signature end
    end
    return preset~='CUSTOM' or ccAny
end

local function tierFor(cat)
    if cat=='STUN' or cat=='FEAR' or cat=='ROOT' or cat=='SLOW' or cat=='SILENCE' or cat=='INCAP' or cat=='DISARM' or cat=='INTERRUPT' or cat=='IMMUNITY' or cat=='BOSS' then return 'LARGE' end
    if cat=='DEFENSIVE' or cat=='DAMAGE_REDUCTION' or cat=='ABSORPTION' or cat=='OFFENSIVE' or cat=='HEALREDUCE' or cat=='TAUNT' or cat=='RAID' then return 'MEDIUM' end
    return 'SMALL'
end

local function nearestQuickSizeLevel(scale)
    scale = tonumber(scale) or 1.00
    local bestLevel, bestDistance = 5, math.huge
    for level = 1, 10 do
        local distance = math.abs(scale - QUICK_SCALE_BY_LEVEL[level])
        if distance < bestDistance then
            bestLevel, bestDistance = level, distance
        end
    end
    return bestLevel
end

local function syncQuickSizeFromScale(scale)
    local level = nearestQuickSizeLevel(scale)
    db.quickSizeLevel = level
    db.auraScale = QUICK_SCALE_BY_LEVEL[level]
    return level, db.auraScale
end

-- Forever runtime mirrors the persisted 1-10 GODMODE size. The dedicated
-- SavedVariables/scalar value is authoritative; Blizzard CVars are output mirrors only.
-- This prevents beta updates from silently changing an existing user's size.

local function setSessionQuickSizeLevel(level)
    sessionQuickSizeLevel = clamp(math.floor(tonumber(level) or 6), 1, 10)
    db.quickSizeLevel = sessionQuickSizeLevel
    db.auraScale = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
    return db.auraScale
end

local function getQuickContainerScale()
    -- Forever-only rebuilt size engine.  Runtime size is authoritative and does
    -- not read old profile/SavedVariables size state.
    return QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
end

-- Countdown text must stay physically small while the aura row itself grows.
-- Walk descendants because Forever/Blizzard can nest the countdown FontString
-- below a Cooldown child instead of exposing it directly on the aura button.
local function getSavedCountdownTextSize()
    local size = tonumber(db and db.countdownTextSize)
    if not size then
        local p = Addon.db and Addon.db.profile
        local t = p and p.themes and p.themes[(p.godmodeAutoFitEnabled and 'godmode_autofit') or 'nameplates']
        size = tonumber(t and t.fontSize) or 18
    end
    local af = Addon.db and Addon.db.profile and Addon.db.profile.godmodeAutoFitEnabled
    if af then
        local t = Addon.db.profile.themes and Addon.db.profile.themes.godmode_autofit
        local slider = math.max(0, math.min(99, tonumber(t and t.fontSize) or 99))
        size = 5 + 10 * slider / 99
        -- Nameplate icons are deliberately smaller than action buttons.
        local icon = tonumber(db and (db.iconSize or db.auraIconSize))
        if icon and icon > 0 then size = math.min(size, math.max(3, icon * 0.56)) end
    end
    return clamp(math.floor(size + 0.5), 1, af and 15 or 48)
end

-- 70170-safe countdown styling. Only the Cooldown countdown FontString is
-- touched: icon size, stack text, borders and aura geometry are never changed.
-- Reapplying this is cheap and deterministic, and prevents Blizzard's secure
-- AuraContainer from restoring the tiny/bottom-aligned native text after updates.
local function styleCountdownFontString(cooldown, sizeOnly)
    if not cooldown or isForbiddenObject(cooldown) then return end

    -- NPC NAMEPLATE AURAS are owned by this renderer, so their cooldowns must
    -- use the exact same Nameplates theme formatter as every other nameplate
    -- cooldown.  The old secure-aura path only copied the font SIZE, leaving
    -- Blizzard's native white countdown color/format on these buttons.
    if not sizeOnly then
        local profile = Addon.db and Addon.db.profile
        local theme = profile and profile.themes and profile.themes[(profile.godmodeAutoFitEnabled and 'godmode_autofit') or 'nameplates']
        if theme and Addon.CreateCountdownFormatter and cooldown.SetCountdownFormatter then
            local okFmt, formatter = pcall(Addon.CreateCountdownFormatter, Addon, theme)
            if okFmt and formatter then
                pcall(cooldown.SetCountdownFormatter, cooldown, formatter)
                cooldown._ogmActionColorFormatter = formatter
                cooldown._ogmActionColorSource = theme
            end
        end
    
        -- Keep swipe/edge/bling/reverse in the same Nameplates theme as well.
        if theme then
            local function state(value, fallback)
                if value == 'always' then return true end
                if value == 'never' then return false end
                return fallback
            end
            local enabled = theme.themeCooldown ~= false
            if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, enabled and state(theme.drawSwipe, true)) end
            if cooldown.SetDrawEdge then pcall(cooldown.SetDrawEdge, cooldown, enabled and state(theme.drawEdge, true)) end
            if cooldown.SetDrawBling then pcall(cooldown.SetDrawBling, cooldown, enabled and state(theme.drawBling, true)) end
            if cooldown.SetReverse then pcall(cooldown.SetReverse, cooldown, enabled and state(theme.reverse, false)) end
            if cooldown.SetSwipeColor then
                if theme.themeSwipeColor and theme.swipeColor and Addon.HexToRGBA then
                    if not cooldown._ogmCustomSwipeApplied and cooldown.GetSwipeColor then
                        local ok, r0,g0,b0,a0 = pcall(cooldown.GetSwipeColor, cooldown)
                        if ok and type(r0)=='number' and type(g0)=='number' and type(b0)=='number' and type(a0)=='number' then
                            cooldown._ogmOriginalSwipeRGBA = {r0,g0,b0,a0}
                        end
                    end
                    local r,g,b,a = Addon.HexToRGBA(theme.swipeColor)
                    pcall(cooldown.SetSwipeColor, cooldown, r,g,b,a)
                    cooldown._ogmCustomSwipeApplied = true
                elseif cooldown._ogmCustomSwipeApplied then
                    -- Restore the cooldown's original tint, not a hard-coded
                    -- dark color. Never alter the saved theme or profile.
                    local original = cooldown._ogmOriginalSwipeRGBA
                    if original then
                        pcall(cooldown.SetSwipeColor, cooldown, original[1], original[2], original[3], original[4])
                    end
                    cooldown._ogmCustomSwipeApplied = nil
                end
            end
        end
    
    end

    if not cooldown.GetCountdownFontString then return end
    local ok, fs = pcall(cooldown.GetCountdownFontString, cooldown)
    if not ok or not fs or isForbiddenObject(fs) or not fs.GetFont or not fs.SetFont then return end

    -- SIZE ONLY. Preserve the renderer, font face, outline/flags, anchor, scale,
    -- alpha, formatter and all Blizzard/GODMODE ownership exactly as they are.
    local okFont, path, currentSize, flags = pcall(fs.GetFont, fs)
    if not okFont or not path then return end
    currentSize = tonumber(currentSize)
    local requested = getSavedCountdownTextSize()

    -- Outside combat Forever accepts SetFont normally. During combat 70170 can
    -- silently reject SetFont on the protected nameplate AuraButton FontString.
    -- That is why the old control only became visible on the NEXT mob.
    -- MiniAuras-inspired visual change guard: do not call protected font setters
    -- again when the live Blizzard FontString already has the requested size.
    -- Read the actual font on every visit (not a cached aura result), so a newly
    -- recycled/reinitialized button is always restyled correctly.
    local sizeMatches = currentSize and math.abs(currentSize - requested) < 0.01
    if sizeMatches then
        local okScale, scale = pcall(fs.GetScale, fs)
        if okScale and type(scale) == 'number' and math.abs(scale - 1) < 0.001 then
            return
        end
        if fs.SetScale then pcall(fs.SetScale, fs, 1) end
        return
    end
    -- If Blizzard rejected a font update earlier, retain the proven fallback.
    -- Never cache live aura data, icons, or cooldown values.
    pcall(fs.SetFont, fs, path, requested, flags)
    local appliedSize = nil
    local okVerify, _, verifySize = pcall(fs.GetFont, fs)
    if okVerify then appliedSize = tonumber(verifySize) end
    if appliedSize and math.abs(appliedSize - requested) < 0.01 then
        if fs.SetScale then pcall(fs.SetScale, fs, 1) end
    elseif currentSize and currentSize > 0 and fs.SetScale then
        pcall(fs.SetScale, fs, requested / currentSize)
    end
end

local ownedCountdowns = setmetatable({}, {__mode='k'})

-- Reuse traversal state and avoid allocating a closure, weak table, and
-- children array every time a nameplate is revisited during camera movement.
-- Native Blizzard aura changes still update the cooldown through SetCooldown.
local countdownStyleSeen = {}
local countdownStyleVisited = {}
local countdownStyleBusy = false
local visitCountdownStyle
local function visitCountdownChildren(depth, ...)
    for i = 1, select('#', ...) do
        visitCountdownStyle(select(i, ...), depth)
    end
end
local function countdownChildrenCall(f, d) visitCountdownChildren(d, f:GetChildren()) end
visitCountdownStyle = function(frame, depth)
    if not frame or depth > 6 or countdownStyleSeen[frame] or isForbiddenObject(frame) then return end
    countdownStyleSeen[frame] = true
    countdownStyleVisited[#countdownStyleVisited + 1] = frame
    local cd = frame.Cooldown or frame.cooldown or frame.CooldownFrame or frame.cooldownFrame
    if cd then styleCountdownFontString(cd) end
    if frame.GetObjectType then
        local ok, typ = pcall(frame.GetObjectType, frame)
        -- Some Blizzard buttons expose their cooldown as both a named member
        -- and the frame itself. Style it only once per traversal.
        if ok and typ == 'Cooldown' and cd ~= frame then styleCountdownFontString(frame) end
    end
    if frame.GetChildren then
        -- No {frame:GetChildren()} allocation. Errors are isolated as before.
        pcall(countdownChildrenCall, frame, depth + 1)
    end
end
local function applyNameplateCountdownTextStyle(root)
    if not root or isForbiddenObject(root) or countdownStyleBusy then return end
    countdownStyleBusy = true
    visitCountdownStyle(root, 0)
    for i = #countdownStyleVisited, 1, -1 do
        countdownStyleSeen[countdownStyleVisited[i]] = nil
        countdownStyleVisited[i] = nil
    end
    countdownStyleBusy = false
end

local function rowGap(basePixels)
    return math.floor((tonumber(basePixels) or 0) * getQuickContainerScale() + 0.5)
end

local ownedPMH = setmetatable({}, { __mode = "k" })
local enforcingPMH = setmetatable({}, { __mode = "k" })
local managedContainers = setmetatable({}, { __mode = "k" })

local function applySmartAuraStyle(container)
    if not container or not container.GetChildren then return end
    -- Live combat changes are allowed only on safe, non-protected objects.
    if not canModifyObject(container) then return end

    local ok, children = pcall(function() return { container:GetChildren() } end)
    if not ok or type(children) ~= "table" then return end

    for _, child in ipairs(children) do
        if child and not isForbiddenObject(child) and (not inCombatLockdown() or not isProtectedObject(child)) then
            local data = childAuraData(child)
            local hasIdentity = data.spellId or data.name or data.debuffType
            local cat = auraCategory(data)
            local allow = categoryAllowed(cat) -- GODMODE filter owns NPC nameplate aura visibility; unknown auras classify as DOT and must not bypass Custom

            -- Visibility/filtering.
            if child.SetShown then
                pcall(child.SetShown, child, allow)
            end

            -- Never resize individual aura children here. Blizzard/Plater calculate
            -- child anchors from their own icon geometry; changing SetSize after layout
            -- makes neighboring debuffs overlap. GODMODE sizes the complete container
            -- instead, so icon size and spacing scale together as one stable row.

            -- Never create/manipulate an addon texture on a forbidden Blizzard
            -- aura child. On safe children we can keep the priority glow.
            if allow and child.CreateTexture then
                local border = child._ogmPriorityBorder
                if border and (isForbiddenObject(border) or (inCombatLockdown() and isProtectedObject(border))) then
                    border = nil
                    child._ogmPriorityBorder = nil
                end

                if not border then
                    local okCreate, created = pcall(child.CreateTexture, child, nil, "OVERLAY")
                    if okCreate and created and not isForbiddenObject(created) and (not inCombatLockdown() or not isProtectedObject(created)) then
                        border = created
                        pcall(border.SetAllPoints, border)
                        pcall(border.SetTexture, border, "Interface/Buttons/UI-ActionButton-Border")
                        pcall(border.SetBlendMode, border, "ADD")
                        child._ogmPriorityBorder = border
                    end
                end

                if border and not isForbiddenObject(border) and (not inCombatLockdown() or not isProtectedObject(border)) then
                    local show =
                        (cat == "INTERRUPT" and db.glowInterrupts)
                        or (cat == "IMMUNITY" and db.glowImmunities)
                        or ((cat == "STUN" or cat == "FEAR" or cat == "ROOT" or cat == "SLOW"
                            or cat == "SILENCE" or cat == "INCAP" or cat == "DISARM")
                            and db.glowCC)

                    if border.SetShown then
                        pcall(border.SetShown, border, not not show)
                    end

                    if border.SetVertexColor then
                        if cat == "INTERRUPT" then
                            pcall(border.SetVertexColor, border, .65, .30, 1.00)
                        elseif cat == "IMMUNITY" then
                            pcall(border.SetVertexColor, border, .20, .60, 1.00)
                        elseif cat == "ROOT" or cat == "SLOW" then
                            -- Same semantic CC color used by GODMODE frame alerts: roots/slows = cyan-blue.
                            pcall(border.SetVertexColor, border, .20, .55, 1.00)
                        elseif cat == "STUN" then
                            pcall(border.SetVertexColor, border, 1.00, .10, .10)
                        elseif cat == "FEAR" or cat == "INCAP" then
                            pcall(border.SetVertexColor, border, 1.00, .82, .15)
                        elseif cat == "SILENCE" or cat == "DISARM" then
                            pcall(border.SetVertexColor, border, .65, .30, 1.00)
                        else
                            pcall(border.SetVertexColor, border, 1, 1, 1)
                        end
                    end
                end
            end
        end
    end
end
-- End Smart Aura System -----------------------------------------------------

local styled = setmetatable({}, { __mode = "k" })


local function setContainerEnabled(container, enabled)
    if not container then return end
    managedContainers[container] = true

    if not canModifyObject(container) then return end

    if enabled then
        if container.SetAlpha then pcall(container.SetAlpha, container, 1) end
        if container.Show then pcall(container.Show, container) end
    else
        if container.SetAlpha then pcall(container.SetAlpha, container, 0) end
        if container.Hide then pcall(container.Hide, container) end
    end
end
local stopOwnedNameplateAuras -- implemented after the secure aura lifecycle definitions
local function updateManagedVisibility()
    for container in pairs(managedContainers) do
        setContainerEnabled(container, db.enabled)
    end
    if db.enabled == false and stopOwnedNameplateAuras then
        stopOwnedNameplateAuras()
    end
end

local function getPMHAnchor(plate)
    -- Match GODMODE Nameplates' own aura anchor exactly.  The previous
    -- compatibility code could select one of the hidden/native health bars
    -- before the real CustomMobHealthBar, which made the Move NPC overlay and
    -- the visible aura row use different coordinate spaces.
    return plate and (plate.CustomMobHealthBar
        or plate.MobHealthBar
        or plate)
end

local suppressPMHManualTimers -- forward declaration; used by enforcePMHContainer below

-- Performance-safe GODMODE Nameplates ownership.
-- Do not hook external aura-container Show/SetPoint methods and do not create
-- proxy anchors. Those paths can be called repeatedly by the nameplate addon
-- during UNIT_AURA refreshes and previously caused recursive hook storms / C
-- stack overflows. We only style a discovered container once per explicit
-- event/refresh and otherwise let its owner handle layout.
local function enforcePMHContainer(container)
    -- True Compatibility release: never restyle an external nameplate aura row
    -- once Nameplates has been handed back to the selected provider.
    if Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates') then return end
    local info = ownedPMH[container]
    if not info or enforcingPMH[container] or not db.enabled then return end
    if isForbiddenObject(container) then return end

    local previousGuard = enforcingPMH[container]
    enforcingPMH[container] = true

    db.auraScale = clamp(db.auraScale, 0.60, 1.50)
    local containerScale = getQuickContainerScale()
    if info.kind and Addon.ForeverAuraText and Addon.ForeverAuraText.GetExternalIconScale then
        containerScale = containerScale * Addon.ForeverAuraText:GetExternalIconScale(info.kind)
    end
    if container.SetScale then pcall(container.SetScale, container, containerScale) end

    -- Do not fight GODMODE Nameplates' SetPoint lifecycle here. Repeated
    -- re-anchoring is expensive and can recurse through third-party hooks.
    pcall(function()
        container.PMHBuilderAnchorKey = "OMNICC_GODMODE_OWNED"
    end)

    applySmartAuraStyle(container)
    suppressPMHManualTimers(container)
    if info.kind and Addon.ForeverAuraText and Addon.ForeverAuraText.StyleExternalContainer then
        Addon.ForeverAuraText:StyleExternalContainer(container, info.kind)
    end
    applyNameplateCountdownTextStyle(container)
    enforcingPMH[container] = previousGuard
end

local function suppressPMHManualTimer(icon)
    if not icon or isForbiddenObject(icon) then return end
    local timer = icon.timer
    if not timer or isForbiddenObject(timer) then return end

    -- One-shot suppression only. Do not hook FontString:Show(); the external
    -- addon may refresh these timers frequently and a Show hook adds work to
    -- every aura update. OmniCC's own countdown remains authoritative when the
    -- external row is discovered.
    pcall(timer.SetText, timer, "")
    pcall(timer.Hide, timer)
end

suppressPMHManualTimers = function(container)
    if not container or isForbiddenObject(container) then return end
    local icons = container.icons
    if type(icons) == "table" then
        for _, icon in pairs(icons) do
            suppressPMHManualTimer(icon)
        end
    end
end

local function ownPMHContainer(container, plate, extraY, kind)
    if not container or not plate then return end
    local normalizedKind = kind == 'BUFF' and 'BUFF' or 'DEBUFF'
    ownedPMH[container] = { plate = plate, extraY = extraY or 0, kind = normalizedKind }

    pcall(function()
        container.OGMNameplateAura = true
        container.OGMNameplateAuraKind = normalizedKind
    end)
    managedContainers[container] = true
    enforcePMHContainer(container)
end

local function styleContainer(container, unitFrame, anchorFrame, extraY, kind)
    if not container or not unitFrame then return end
    -- Compatibility Center Nameplates CHECKED = external provider owns the row.
    -- Do not resize/reanchor/style the provider's icons or countdown text.
    if Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates') then return end
    managedContainers[container] = true
    local normalizedKind = kind == 'BUFF' and 'BUFF' or 'DEBUFF'
    pcall(function()
        container.OGMNameplateAura = true
        container.OGMNameplateAuraKind = normalizedKind
    end)

    anchorFrame = anchorFrame or unitFrame

    if not canModifyObject(container)
        or not canModifyObject(unitFrame)
        or not canModifyObject(anchorFrame) then
        return
    end

    db.auraScale = clamp(db.auraScale, 0.60, 1.50)
    db.offsetX = clamp(db.offsetX, -1000, 1000)
    db.offsetY = clamp(db.offsetY, -500, 1000)

    setContainerEnabled(container, true)

    if container.SetScale then pcall(container.SetScale, container, getQuickContainerScale()) end
    if container.ClearAllPoints then pcall(container.ClearAllPoints, container) end
    if container.SetPoint then
        pcall(container.SetPoint, container, "BOTTOM", anchorFrame, "TOP",
            db.offsetX, db.offsetY + (extraY or 0))
    end
    if container.SetFrameStrata then pcall(container.SetFrameStrata, container, "HIGH") end
    if container.SetAlpha then pcall(container.SetAlpha, container, 1) end
    if container.Show then pcall(container.Show, container) end

    if unitFrame.GetFrameLevel and container.SetFrameLevel then
        local okLevel, level = pcall(unitFrame.GetFrameLevel, unitFrame)
        if okLevel and safeNumber(level) then
            pcall(container.SetFrameLevel, container, level + 30)
        end
    end

    applySmartAuraStyle(container)
    -- Plater Forever AuraContainers create/recycle their buttons after the
    -- container itself exists. Apply the same GODMODE external-aura styling
    -- used by our other Forever nameplate integrations on every targeted
    -- refresh, including GODMODE timer/font ownership.
    if Addon.ForeverAuraText and Addon.ForeverAuraText.StyleExternalContainer then
        pcall(Addon.ForeverAuraText.StyleExternalContainer, Addon.ForeverAuraText, container, normalizedKind)
    end
    applyNameplateCountdownTextStyle(container)
    styled[container] = true
end
-- Forward declaration: stylePlate must be able to invoke the independent GODMODE
-- AuraContainer renderer for every nameplate implementation (Threat Plates,
-- Platynator, Blizzard, etc.).
local updateOwnedDebuffRow
local reanchorOwnedDebuffRows
local refreshOwnedDebuffRows
local applyLiveQuickControls

-- v16: while GODMODE owns the nameplate-aura scope, suppress any competing
-- aura presentation that is actually attached to the nameplate tree.  This is
-- provider-independent: Blizzard, Threat Plates, Plater, Platynator, ElvUI,
-- etc. do not need to be named here.  GODMODE's own container is UIParent-owned
-- and marked OGMGodmodeNameplateCooldown, so it is never part of this tree.
local suppressedNative = setmetatable({}, {__mode='k'})
-- Performance: remember only physical plates GODMODE actually suppressed.
-- Never recursively walk a normal/independent nameplate just to discover there is nothing to restore.
local suppressedPlates = setmetatable({}, {__mode='k'})
local function looksLikeAuraPresentation(frame)
    if not frame or isForbiddenObject(frame) then return false end
    if frame.OGMGodmodeNameplateCooldown or frame.OGMNameplateAura then return false end
    local n=''
    if frame.GetName then local ok,v=pcall(frame.GetName,frame); if ok and type(v)=='string' then n=v end end
    if n:find('Aura',1,true) or n:find('Buff',1,true) or n:find('Debuff',1,true) or n:find('CrowdControl',1,true) then return true end
    -- Plater Forever frequently uses unnamed/recycled aura containers.  They
    -- cannot be identified from GetName(), but the actual aura rows expose
    -- PlaterBuffList / NextAuraIcon.  Classify the ROW only; never the owning
    -- unit/nameplate frame.
    local okPlater,list,nextIcon=pcall(function() return frame.PlaterBuffList,frame.NextAuraIcon end)
    if okPlater and (type(list)=='table' or safeNumber(nextIcon)) then return true end
    -- IMPORTANT: do not classify a whole nameplate as an aura presentation
    -- merely because it OWNS BuffDisplay/DebuffDisplay/CrowdControlDisplay.
    -- Platynator's root nameplate exposes those fields; treating the owner as
    -- an aura row hides the entire healthbar/nameplate.  Only the actual aura
    -- container/button object may be suppressed here.
    if frame.SetUnit and (frame.AddAuraGroup or frame.UpdateAllAuras) then return true end
    return false
end
local function suppressCompetingAuraTree(root,depth)
    if not root or depth>8 or isForbiddenObject(root) then return end
    if looksLikeAuraPresentation(root) then
        if not suppressedNative[root] then
            local shown=nil
            if root.IsShown then local ok,v=pcall(root.IsShown,root); if ok then shown=v end end
            suppressedNative[root]={shown=shown}
        end
        if root.SetEnabled then pcall(root.SetEnabled,root,false) end
        -- Hide alone is not durable: Blizzard's AuraContainer and several
        -- nameplate addons Show() the row again on every UNIT_AURA.  Alpha is
        -- presentation-only and survives those internal Show/layout passes.
        if root.SetAlpha then pcall(root.SetAlpha,root,0) end
        if root.EnableMouse then pcall(root.EnableMouse,root,false) end
        if root.Hide then pcall(root.Hide,root) end
        return
    end
    -- Some nameplate addons (notably Platynator) expose their aura anchor
    -- frames as fields on the nameplate root. Walk those children explicitly
    -- while leaving the owning nameplate itself completely untouched.
    local okDisplays,b,d,c=pcall(function()
        return root.BuffDisplay,root.DebuffDisplay,root.CrowdControlDisplay
    end)
    if okDisplays then
        if b and b ~= root then suppressCompetingAuraTree(b,depth+1) end
        if d and d ~= root then suppressCompetingAuraTree(d,depth+1) end
        if c and c ~= root then suppressCompetingAuraTree(c,depth+1) end
    end
    if not root.GetChildren then return end
    local ok,children=pcall(function() return {root:GetChildren()} end)
    if not ok then return end
    for _,child in ipairs(children) do suppressCompetingAuraTree(child,depth+1) end
end
local function restoreSuppressedAuraTree(root,depth)
    if not root or depth>8 or isForbiddenObject(root) then return end
    local state=suppressedNative[root]
    if state then
        -- Friendly plates must be handed completely back to Blizzard. A frame
        -- suppressed earlier while this physical nameplate represented an enemy
        -- can be recycled for a friendly unit, so merely skipping suppression is
        -- not enough: restore the presentation state we changed.
        if root.SetAlpha then pcall(root.SetAlpha,root,1) end
        if root.SetEnabled then pcall(root.SetEnabled,root,true) end
        if root.EnableMouse then pcall(root.EnableMouse,root,true) end
        if state.shown ~= false and root.Show then pcall(root.Show,root) end
        suppressedNative[root]=nil
        return
    end
    local okDisplays,b,d,c=pcall(function()
        return root.BuffDisplay,root.DebuffDisplay,root.CrowdControlDisplay
    end)
    if okDisplays then
        if b and b ~= root then restoreSuppressedAuraTree(b,depth+1) end
        if d and d ~= root then restoreSuppressedAuraTree(d,depth+1) end
        if c and c ~= root then restoreSuppressedAuraTree(c,depth+1) end
    end
    if not root.GetChildren then return end
    local ok,children=pcall(function() return {root:GetChildren()} end)
    if not ok then return end
    for _,child in ipairs(children) do restoreSuppressedAuraTree(child,depth+1) end
end
local function restoreSuppressedNameplateAuras(plate)
    if not plate or not suppressedPlates[plate] then return end
    restoreSuppressedAuraTree(plate,0)
    local uf=plate and (plate.UnitFrame or plate.unitFrame)
    if uf then
        local keys={'AuraContainer','BuffContainer','DebuffContainer','BuffDisplay','DebuffDisplay','CrowdControlDisplay','Auras','BuffFrame','BuffFrame2','DebuffFrame'}
        for _,k in ipairs(keys) do
            local ok,v=pcall(function() return uf[k] end)
            if ok and v then restoreSuppressedAuraTree(v,0) end
        end
    end
    suppressedPlates[plate]=nil
end
local function platerCompatibilityMode()
    -- Three-state contract for Plater:
    --   master OFF                         -> independent (do not suppress Plater)
    --   master ON + Plater + NP unchecked -> GODMODE owns; suppress Plater auras
    --   master ON + Plater + NP checked   -> Plater owns; restore/release fully
    local root=Addon.db and Addon.db.global
    local center=root and root.compatibilityCenter
    if type(center)~='table' or center.enabled==false then return 'independent' end
    local cfg=center.addons and center.addons.plater
    if type(cfg)~='table' or cfg.enabled~=true then return 'independent' end
    if type(cfg.scopes)=='table' and cfg.scopes.nameplates==true then return 'plater' end
    return 'godmode'
end
local function suppressCompetingNameplateAuras(plate)
    if platerCompatibilityMode() ~= 'godmode' then return end
    if suppressedPlates[plate] then return end
    suppressedPlates[plate]=true
    suppressCompetingAuraTree(plate,0)
    local uf=plate and (plate.UnitFrame or plate.unitFrame)
    if uf then
        local keys={'AuraContainer','BuffContainer','DebuffContainer','BuffDisplay','DebuffDisplay','CrowdControlDisplay','Auras','BuffFrame','BuffFrame2','DebuffFrame'}
        for _,k in ipairs(keys) do
            local ok,v=pcall(function() return uf[k] end)
            if ok and v then suppressCompetingAuraTree(v,0) end
        end
    end
end

-- v19: Blizzard itself owns a second NPC aura presentation through the native
-- nameplateEnemyNpcAuraDisplay setting.  Hiding frame children cannot reliably
-- suppress it because its AuraContainers may be UIParent-owned/rebuilt.  Disable
-- the source setting while GODMODE owns nameplate auras, and restore it when the
-- Compatibility Center releases that scope.  This is a secure CVar, so writes are
-- intentionally restricted to out-of-combat lifecycle/config passes.
local nativeNpcAuraPrior
local NATIVE_AURA_PRIOR_KEY = 'nativeNpcAuraPrior'
-- 1.3.8 Forever: Blizzard 12.x no longer exposes friendly-player auras as a
-- legacy BuffFrame/AuraContainer that can be reliably found by walking the
-- nameplate tree. Blizzard_NamePlateAuras owns BuffListFrame/DebuffListFrame
-- and drives them from FRIENDLY_PLAYER_AURA_DISPLAY_CVAR.  Own the SOURCE,
-- not the generated frames, while GODMODE's friendly secure lane is active.
local nativeFriendlyPlayerAuraPrior
local NATIVE_FRIENDLY_AURA_PRIOR_KEY = 'nativeFriendlyPlayerAuraPrior'
local function friendlyPlayerAuraCVarName()
    local c = _G.NamePlateConstants
    return c and c.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR or 'nameplateFriendlyPlayerAuraDisplay'
end
local function getNativeCVar(name)
    if C_CVar and C_CVar.GetCVar then local ok,v=pcall(C_CVar.GetCVar,name); if ok then return v end end
    if GetCVar then local ok,v=pcall(GetCVar,name); if ok then return v end end
end
local function setNativeCVar(name,value)
    if inCombatLockdown() then return false end
    value=tostring(value)
    if C_CVar and C_CVar.SetCVar then local ok=pcall(C_CVar.SetCVar,name,value); if ok then return true end end
    if SetCVar then local ok=pcall(SetCVar,name,value); if ok then return true end end
    return false
end
local function syncNativeFriendlyPlayerAuraOwnership()
    local external = Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates')
    local name = friendlyPlayerAuraCVarName()
    local current = getNativeCVar(name)
    if current == nil then return end
    if not external and db.enabled ~= false then
        if nativeFriendlyPlayerAuraPrior == nil then
            nativeFriendlyPlayerAuraPrior = db[NATIVE_FRIENDLY_AURA_PRIOR_KEY]
            if nativeFriendlyPlayerAuraPrior == nil and current ~= '0' then
                nativeFriendlyPlayerAuraPrior = current
            end
        end
        if nativeFriendlyPlayerAuraPrior ~= nil then
            db[NATIVE_FRIENDLY_AURA_PRIOR_KEY] = tostring(nativeFriendlyPlayerAuraPrior)
        end
        if current ~= '0' then setNativeCVar(name,0) end
    else
        local prior = nativeFriendlyPlayerAuraPrior or db[NATIVE_FRIENDLY_AURA_PRIOR_KEY]
        if prior ~= nil then setNativeCVar(name,prior) end
        nativeFriendlyPlayerAuraPrior=nil
        db[NATIVE_FRIENDLY_AURA_PRIOR_KEY]=nil
    end
end
local function restoreNativeFriendlyPlayerAuraCVar()
    local prior=nativeFriendlyPlayerAuraPrior or db[NATIVE_FRIENDLY_AURA_PRIOR_KEY]
    if prior ~= nil then
        setNativeCVar(friendlyPlayerAuraCVarName(),prior)
        nativeFriendlyPlayerAuraPrior=nil
        db[NATIVE_FRIENDLY_AURA_PRIOR_KEY]=nil
    end
end
local function syncNativeNpcAuraOwnership()
    local external = Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates')
    local current = getNativeCVar('nameplateEnemyNpcAuraDisplay')
    if current == nil then return end
    if not external and db.enabled ~= false then
        if nativeNpcAuraPrior == nil then
            nativeNpcAuraPrior = db[NATIVE_AURA_PRIOR_KEY]
            if nativeNpcAuraPrior == nil and current ~= '0' then nativeNpcAuraPrior=current end
        end
        if nativeNpcAuraPrior ~= nil then db[NATIVE_AURA_PRIOR_KEY]=tostring(nativeNpcAuraPrior) end
        if current ~= '0' then setNativeCVar('nameplateEnemyNpcAuraDisplay',0) end
    else
        local prior=nativeNpcAuraPrior or db[NATIVE_AURA_PRIOR_KEY]
        if prior ~= nil then setNativeCVar('nameplateEnemyNpcAuraDisplay',prior) end
        nativeNpcAuraPrior=nil; db[NATIVE_AURA_PRIOR_KEY]=nil
    end
end
local function restoreNativeNpcAuraCVar()
    local prior=nativeNpcAuraPrior or db[NATIVE_AURA_PRIOR_KEY]
    if prior ~= nil then
        setNativeCVar('nameplateEnemyNpcAuraDisplay',prior)
        nativeNpcAuraPrior=nil
        db[NATIVE_AURA_PRIOR_KEY]=nil
    end
end

local function stylePlate(plate)
    if not plate then return end

    -- v15 SINGLE-RENDERER CONTRACT (Forever):
    -- GODMODE no longer discovers, restyles, moves, scales, enables, disables,
    -- or mirrors any Blizzard/Plater/ThreatPlates/Platynator/nameplate-addon
    -- AuraContainer.  Those were the legacy path that could produce a second
    -- GODMODE-controlled row alongside the new independent renderer.
    --
    -- The only GODMODE nameplate aura system is updateOwnedDebuffRow(), whose
    -- CustomAuraContainerTemplate is UIParent-owned and follows the Blizzard
    -- nameplate unit token.  Compatibility ownership only decides whether that
    -- one renderer is active; it never creates a second rendering path.
    -- Native CVar ownership is synchronized on lifecycle/config events, not once
    -- per visible nameplate. Re-reading/writing CVars in this camera hot path can
    -- cascade CVAR_UPDATE work while many plates are entering view.
    local unitFrame = plate.UnitFrame or plate.unitFrame or plate
    local unit = plate.namePlateUnitToken or plate.unitToken or (unitFrame and unitFrame.unit)
    -- Plater ownership is explicit.  With compatibility disabled we leave
    -- Plater independent; with Plater Nameplates released we restore everything;
    -- only GODMODE-owned Plater nameplate auras are suppressed.  Friendly rows
    -- remain untouched as before.
    local platerMode=platerCompatibilityMode()
    if platerMode ~= 'godmode' or (unit and UnitIsFriend('player',unit)) then
        restoreSuppressedNameplateAuras(plate)
    else
        suppressCompetingNameplateAuras(plate)
    end
    if unit and updateOwnedDebuffRow then
        updateOwnedDebuffRow(unit, plate)
    end
end

-- Full-refresh requests are coalesced and drained in small batches.  Normal
-- NAME_PLATE_UNIT_ADDED / UNIT_AURA paths remain immediate: this queue only
-- replaces the old synchronous all-visible-plates sweep.
local _ogmFullRefreshPending = false
local _ogmFullRefreshPlates = nil
local _ogmFullRefreshIndex = 1
local _ogmFullRefreshRetry = false
-- Frame-time governor: stop the optional all-plate restyle sweep after a
-- small CPU budget, rather than processing four potentially expensive plates
-- in the same render frame. Always process at least one to guarantee progress.
local function _ogmDrainFullRefresh()
    local plates = _ogmFullRefreshPlates
    if not plates then
        _ogmFullRefreshPending = false
        return
    end
    local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local started = clock and clock() or nil
    local processed = 0
    while _ogmFullRefreshIndex <= #plates and processed < 4 do
        local plate = plates[_ogmFullRefreshIndex]
        _ogmFullRefreshIndex = _ogmFullRefreshIndex + 1
        processed = processed + 1
        if plate and not isForbiddenObject(plate) then
            local okStyle = pcall(stylePlate, plate)
            if not okStyle then _ogmFullRefreshRetry = true end
        end
        if started and clock() - started >= 1.0 then break end
    end
    if _ogmFullRefreshIndex <= #plates then
        C_Timer.After(0, _ogmDrainFullRefresh)
        return
    end
    _ogmFullRefreshPlates = nil
    _ogmFullRefreshPending = false
    if _ogmFullRefreshRetry then
        queueCombatRefresh()
    elseif not inCombatLockdown() then
        pendingCombatRefresh = false
    end
    _ogmFullRefreshRetry = false
end
local function refreshAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    -- A new request while the sweep is pending is already covered by its
    -- snapshot.  Direct per-unit events still update live aura visibility.
    if _ogmFullRefreshPending then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    _ogmFullRefreshPlates = plates
    _ogmFullRefreshIndex = 1
    _ogmFullRefreshRetry = false
    _ogmFullRefreshPending = true
    C_Timer.After(0, _ogmDrainFullRefresh)
end
-- Diagnostic wrapper: disabled path is a direct call (no profiling allocations).
local _ogm_diag_original_refreshAll = refreshAll
refreshAll = function(...)
    if not OGM_NP_DIAG.enabled then return _ogm_diag_original_refreshAll(...) end
    return OGM_NP_Measure('Forever.refresh_all',_ogm_diag_original_refreshAll,...)
end
-- Movable global anchor. It is displayed directly over the current target's
-- active aura row (or its expected row position when no aura is currently visible).
local anchor = CreateFrame("Frame", "OmniCC_GODMODE_NameplateMoveAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(220, 64)
anchor:SetFrameStrata("TOOLTIP")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
anchor:SetBackdropColor(0, 0, 0, 0.85)
anchor:SetBackdropBorderColor(1, 0.82, 0, 1)
local anchorText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
anchorText:SetPoint("CENTER")
anchorText:SetText("OmniCC GODMODE\nDrag to move these debuffs")

local function getTargetPlate()
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok then return plate end
end

-- Return the exact base frame used to position the visible aura row.  The
-- move overlay is anchored to this same base with the same X/Y offsets, so it
-- always sits on the debuffs and dragging it moves the real row live.

local function getTargetAuraContainer()
    local plate = getTargetPlate()
    if not plate then return nil end

    -- PlaterMobHealth custom aura containers.
    if plate.MobHealthAuraContainer then
        return plate.MobHealthAuraContainer
    end
    if plate.MobHealthEnemyBuffContainer then
        return plate.MobHealthEnemyBuffContainer
    end

    -- Standard Plater aura frames.
    local uf = plate.unitFrame
    if uf then
        if uf.BuffFrame then return uf.BuffFrame end
        if uf.BuffFrame2 then return uf.BuffFrame2 end
    end

    -- Blizzard nameplate aura container fallbacks.
    local blizz = plate.UnitFrame
    if blizz then
        if blizz.AurasFrame then return blizz.AurasFrame end
        if blizz.BuffFrame then return blizz.BuffFrame end
        if blizz.DebuffFrame then return blizz.DebuffFrame end
    end
end

local function getAnchorBase(plate)
    if not plate then return nil end

    -- PlaterMobHealth custom containers use this exact base in
    -- enforcePMHContainer().
    if plate.MobHealthAuraContainer or plate.MobHealthEnemyBuffContainer then
        return getPMHAnchor(plate)
    end

    -- Standard Plater uses its health bar as the aura-row base.
    local platerFrame = plate.unitFrame
    if platerFrame and (platerFrame.BuffFrame or platerFrame.BuffFrame2) then
        return platerFrame.healthBar or platerFrame
    end

    -- Blizzard fallback mirrors stylePlate()/styleContainer().
    return plate.UnitFrame or plate.unitFrame or plate
end

local function updateAnchor()
    anchor:ClearAllPoints()

    if not db.anchorShown then
        anchor:Hide()
        return
    end

    local plate = getTargetPlate()
    local base = getAnchorBase(plate)
    if not plate or not base then
        anchor:Hide()
        return
    end

    anchor:SetPoint("BOTTOM", base, "TOP", db.offsetX, db.offsetY)
    anchor:Show()
end
anchor:SetScript("OnDragStart", function(self)
    local plate = getTargetPlate()
    local base = getAnchorBase(plate)
    if not plate or not base then return end

    local okScale, scale = pcall(UIParent.GetEffectiveScale, UIParent)
    scale = okScale and safeNumber(scale) or nil
    local okCursor, x, y = pcall(GetCursorPosition)
    x, y = okCursor and safeNumber(x) or nil, okCursor and safeNumber(y) or nil
    if not scale or scale <= 0 or not x or not y then return end
    self._ogmStartCursorX = x / scale
    self._ogmStartCursorY = y / scale
    self._ogmStartOffsetX = tonumber(db.offsetX) or 0
    self._ogmStartOffsetY = tonumber(db.offsetY) or 0

    self:SetScript("OnUpdate", function(frame)
        local okScale, currentScale = pcall(UIParent.GetEffectiveScale, UIParent)
        currentScale = okScale and safeNumber(currentScale) or nil
        local okCursor, cx, cy = pcall(GetCursorPosition)
        cx, cy = okCursor and safeNumber(cx) or nil, okCursor and safeNumber(cy) or nil
        if not currentScale or currentScale <= 0 or not cx or not cy then return end
        cx, cy = cx / currentScale, cy / currentScale

        db.offsetX = clamp(frame._ogmStartOffsetX + (cx - frame._ogmStartCursorX), -300, 300)
        db.offsetY = clamp(frame._ogmStartOffsetY + (cy - frame._ogmStartCursorY), -150, 300)

        -- Persist continuously so reload/crash cannot lose the chosen location.
        persist(false)

        -- v21: move the already-owned GODMODE AuraContainers with the visual
        -- anchor.  This does not acquire/refresh rows; it only changes SetPoint
        -- on the existing UIParent-owned containers, so no old-position copy is
        -- left behind while dragging.
        if reanchorOwnedDebuffRows then pcall(reanchorOwnedDebuffRows) end
        updateAnchor()
    end)
end)

anchor:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    persist()
    if reanchorOwnedDebuffRows then pcall(reanchorOwnedDebuffRows) end
    if refreshOwnedDebuffRows then pcall(refreshOwnedDebuffRows) end
    updateAnchor()
end)

local function setAnchorShown(shown, announce)
    shown = not not shown

    if shown then
        local plate = getTargetPlate()
        local base = getAnchorBase(plate)
        if not plate or not base then
            db.anchorShown = false
            persist()
            updateAnchor()
            print("|cffffd200OmniCC GODMODE:|r Target a visible NPC nameplate first, then press Move NPC.")
            return
        end
    end

    db.anchorShown = shown
    persist()
    if reanchorOwnedDebuffRows then pcall(reanchorOwnedDebuffRows) end
    updateAnchor()

    if announce then
        print("|cffffd200OmniCC GODMODE:|r NPC move anchor " .. (db.anchorShown and "shown" or "hidden"))
    end
end
local applyDebuffSourceMode -- forward declaration; implementation follows secure container setup

-- Small combat-safe control panel. Blizzard Settings cannot open during combat.
local quick = CreateFrame("Frame", "OmniCC_GODMODE_NameplateQuickPanel", UIParent, "BackdropTemplate")
quick:SetSize(370, 325)
quick:SetPoint(db.quickPoint or "CENTER", UIParent, db.quickPoint or "CENTER", tonumber(db.quickX) or 0, tonumber(db.quickY) or 0)
quick:SetFrameStrata("DIALOG")
quick:SetMovable(true)
quick:SetClampedToScreen(true)
quick:EnableMouse(true)
quick:RegisterForDrag("LeftButton")
quick:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
quick:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
quick:SetScript("OnDragStart", quick.StartMoving)
quick:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    db.quickPoint = point or "CENTER"
    db.quickX = tonumber(x) or 0
    db.quickY = tonumber(y) or 0
    persist()
end)
quick:Hide()

local title = quick:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
title:SetWidth(340)
title:SetJustifyH("CENTER")
title:SetWordWrap(true)
title:SetText("OmniCC GODMODE - Nameplates")

local subtitle = quick:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
subtitle:SetWidth(340)
subtitle:SetJustifyH("CENTER")
subtitle:SetWordWrap(true)
subtitle:SetText("Combat-safe size and position controls")
subtitle:SetTextColor(0.75, 0.75, 0.75)

local function makeButton(text, x, y, width, callback)
    local button = CreateFrame("Button", nil, quick, "UIPanelButtonTemplate")
    button:SetSize(width or 86, 26)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local status = quick:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
status:SetPoint("TOP", subtitle, "BOTTOM", 0, -7)
status:SetWidth(340)
status:SetJustifyH("CENTER")
status:SetWordWrap(true)

local function updateStatus()
    status:SetText(string.format("Scale: %.2f   X: %d   Y: %d   %s", db.auraScale, db.offsetX, db.offsetY, db.showAllDebuffs == false and "MY DEBUFFS" or "ALL DEBUFFS"))
end

makeButton("Show Move Anchor", 15, -76, 165, function() setAnchorShown(not db.anchorShown, true) end)
makeButton("Close", 190, -76, 165, function() quick:Hide() end)
makeButton("Scale -", 15, -114, 105, function() Addon.ForeverNameplates:NudgeSize(-1); updateStatus() end)
makeButton("Scale +", 132, -114, 105, function() Addon.ForeverNameplates:NudgeSize(1); updateStatus() end)
makeButton("Reset", 249, -114, 105, function()
    db.enabled, db.auraScale, db.offsetX, db.offsetY = true, defaults.auraScale, defaults.offsetX, defaults.offsetY
    persist()
    updateAnchor(); refreshAll(); updateStatus()
end)
makeButton("Left", 15, -154, 78, function() db.offsetX = db.offsetX - 1; persist(); updateAnchor(); refreshAll(); updateStatus() end)
makeButton("Right", 101, -154, 78, function() db.offsetX = db.offsetX + 1; persist(); updateAnchor(); refreshAll(); updateStatus() end)
makeButton("Up", 187, -154, 78, function() db.offsetY = db.offsetY + 1; persist(); updateAnchor(); refreshAll(); updateStatus() end)
makeButton("Down", 273, -154, 81, function() db.offsetY = db.offsetY - 1; persist(); updateAnchor(); refreshAll(); updateStatus() end)
makeButton("Enable", 15, -194, 165, function()
    db.enabled = true
    persist()
    updateManagedVisibility()
    refreshAll()
    updateStatus()
end)
makeButton("Disable", 190, -194, 165, function()
    db.enabled = false
    persist()
    refreshAll()
    updateManagedVisibility()
    updateStatus()
end)

local combatFull
local function showCombatFullPanel()
    if not combatFull then
        combatFull = CreateFrame("Frame", "OmniCC_GODMODE_CombatFullSettings", UIParent, "BackdropTemplate")
        combatFull:SetSize(540, 510)
        combatFull:SetPoint("CENTER")
        combatFull:SetFrameStrata("DIALOG")
        combatFull:SetFrameLevel(250)
        combatFull:SetClampedToScreen(true)
        combatFull:SetMovable(true)
        combatFull:EnableMouse(true)
        combatFull:RegisterForDrag("LeftButton")
        combatFull:SetScript("OnDragStart", function(self) self:StartMoving() end)
        combatFull:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        combatFull:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        combatFull:SetBackdropColor(0.03, 0.03, 0.03, 0.96)
        combatFull:SetBackdropBorderColor(0.75, 0.55, 0.12, 1)

        local title2 = combatFull:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title2:SetPoint("TOP", 0, -16)
        title2:SetText("OmniCC GODMODE - Full Combat Settings")

        local note = combatFull:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOP", title2, "BOTTOM", 0, -6)
        note:SetWidth(490)
        note:SetJustifyH("CENTER")
        note:SetWordWrap(true)
        note:SetText("Combat-safe settings. These controls work during combat and save immediately.")
        note:SetTextColor(0.75, 0.75, 0.75)

        local function button2(text, x, y, w, cb)
            local b = CreateFrame("Button", nil, combatFull, "UIPanelButtonTemplate")
            b:SetSize(w or 150, 26)
            b:SetPoint("TOPLEFT", x, y)
            b:SetText(text)
            b:SetScript("OnClick", cb)
            return b
        end

        local function slider2(label, minv, maxv, step, x, y, getter, setter)
            local lab = combatFull:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lab:SetPoint("TOPLEFT", x, y)
            lab:SetText(label)
            local val = combatFull:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            val:SetPoint("TOPRIGHT", -28, y)
            local sl = CreateFrame("Slider", nil, combatFull, "OptionsSliderTemplate")
            sl:SetPoint("TOPLEFT", x, y - 24)
            sl:SetWidth(450)
            sl:SetMinMaxValues(minv, maxv)
            sl:SetValueStep(step)
            sl:SetObeyStepOnDrag(true)
            sl.Low:SetText(tostring(minv))
            sl.High:SetText(tostring(maxv))
            sl.Text:SetText("")
            sl:SetScript("OnValueChanged", function(_, v)
                setter(v)
                if step < 1 then val:SetText(string.format("%.2f", v)) else val:SetText(tostring(math.floor(v + 0.5))) end
            end)
            sl._refresh = function()
                local v = getter()
                sl:SetValue(v)
                if step < 1 then val:SetText(string.format("%.2f", v)) else val:SetText(tostring(math.floor(v + 0.5))) end
            end
            return sl
        end

        combatFull.enableBtn = button2("Nameplate Auras: ON", 28, -78, 230, function(self)
            db.enabled = not db.enabled
            persist(); refreshAll(); updateManagedVisibility()
            self:SetText(db.enabled and "Nameplate Auras: ON" or "Nameplate Auras: OFF")
        end)
        combatFull.anchorBtn = button2("Show Move Anchor", 282, -78, 230, function(self)
            setAnchorShown(not db.anchorShown, true)
            self:SetText(db.anchorShown and "Hide Move Anchor" or "Show Move Anchor")
        end)

        combatFull.scaleSlider = slider2("Aura scale", 0.60, 2.00, 0.10, 36, -125,
            function() return db.auraScale end,
            function(v)
                local scale=clamp(v,.60,2.00); setSessionQuickSizeLevel(nearestQuickSizeLevel(scale)); setNativeCVar('nameplateAuraScale',db.auraScale)
                persist(); applyLiveQuickControls(); refreshAll(); updateStatus()
            end)
        combatFull.xSlider = slider2("Horizontal position", -300, 300, 1, 36, -210,
            function() return db.offsetX end,
            function(v) db.offsetX = math.floor(v + 0.5); persist(); updateAnchor(); refreshAll(); updateStatus() end)
        combatFull.ySlider = slider2("Vertical position", -300, 300, 1, 36, -295,
            function() return db.offsetY end,
            function(v) db.offsetY = math.floor(v + 0.5); persist(); updateAnchor(); refreshAll(); updateStatus() end)

        combatFull.sourceBtn = button2("Debuffs: All Players", 28, -383, 484, function(self)
            db.showAllDebuffs = not (db.showAllDebuffs ~= false)
            persist(); applyDebuffSourceMode(); updateStatus()
            self:SetText(db.showAllDebuffs == false and "Debuffs: Mine Only" or "Debuffs: All Players")
        end)

        combatFull.cooldownBtn = button2("Cooldown Appearance", 28, -421, 230, function(self)
            local themes = Addon.db and Addon.db.profile and Addon.db.profile.themes
            if themes then
                local anyOn = false
                for _, theme in pairs(themes) do
                    if type(theme) == "table" and theme.themeCooldown then anyOn = true break end
                end
                for _, theme in pairs(themes) do
                    if type(theme) == "table" then theme.themeCooldown = not anyOn end
                end
                self:SetText((not anyOn) and "Cooldown Appearance: ON" or "Cooldown Appearance: OFF")
            end
        end)
        combatFull.rulesBtn = button2("Enable All Rules", 282, -421, 230, function()
            local rules = Addon.db and Addon.db.profile and Addon.db.profile.rules
            if rules then
                for _, rule in pairs(rules) do
                    if type(rule) == "table" then rule.enabled = true end
                end
            end
            print("|cffffd200OmniCC GODMODE:|r all rules enabled.")
        end)
        button2("Reset Nameplate Position", 28, -459, 230, function()
            db.enabled, db.auraScale, db.offsetX, db.offsetY = true, defaults.auraScale, defaults.offsetX, defaults.offsetY
            persist(); updateAnchor(); refreshAll(); updateStatus()
            if combatFull._refresh then combatFull._refresh() end
        end)
        button2("Close", 282, -459, 230, function() combatFull:Hide() end)

        combatFull._refresh = function()
            combatFull.enableBtn:SetText(db.enabled and "Nameplate Auras: ON" or "Nameplate Auras: OFF")
            combatFull.anchorBtn:SetText(db.anchorShown and "Hide Move Anchor" or "Show Move Anchor")
            combatFull.sourceBtn:SetText(db.showAllDebuffs == false and "Debuffs: Mine Only" or "Debuffs: All Players")
            combatFull.scaleSlider._refresh()
            combatFull.xSlider._refresh()
            combatFull.ySlider._refresh()
            local themes = Addon.db and Addon.db.profile and Addon.db.profile.themes
            local on = false
            if themes then
                for _, theme in pairs(themes) do
                    if type(theme) == "table" and theme.themeCooldown then on = true break end
                end
            end
            combatFull.cooldownBtn:SetText(on and "Cooldown Appearance: ON" or "Cooldown Appearance: OFF")
        end
    end

    combatFull._refresh()
    combatFull:Show()
    combatFull:Raise()
end

local sourceBtn
sourceBtn = makeButton("Debuffs: All Players", 15, -234, 340, function(self)
    db.showAllDebuffs = not (db.showAllDebuffs ~= false)
    persist()
    applyDebuffSourceMode()
    self:SetText(db.showAllDebuffs == false and "Debuffs: Mine Only" or "Debuffs: All Players")
    updateStatus()
end)

makeButton("Full Settings", 15, -274, 340, function()
    local inCombat = (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player"))
    if inCombat then
        showCombatFullPanel()
        return
    end
    quick:Hide()
    local addon = _G.OmniCC_GODMODE or Addon
    if addon and addon.ShowOptionsFrame then
        addon:ShowOptionsFrame()
    elseif C_AddOns and C_AddOns.LoadAddOn then
        local loaded = C_AddOns.LoadAddOn(AddonName .. '_Config')
        if loaded and addon and addon.OpenOptions then addon:OpenOptions() end
    end
end)

local function showQuickPanel()
    updateStatus()
    quick:Show()
    quick:Raise()
end

-- GODMODE Nameplates Forever compatibility ---------------------------------
-- Stability-first path: no UNIT_AURA callbacks, no global UpdateAllAuras hook,
-- no SetPoint/Show hooks and no repeated provider forcing. We discover existing
-- custom rows on explicit nameplate/login events only. This removes the hot
-- refresh path that could generate very high CPU usage in combat.
local function isAddonLoadedSafe(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    return false
end

local function claimGODMODENameplatesPlate(plate)
    if not plate or isForbiddenObject(plate) then return false end
    local claimed = false
    if plate.MobHealthAuraContainer then
        ownPMHContainer(plate.MobHealthAuraContainer, plate, 0, 'DEBUFF')
        claimed = true
    end
    if plate.MobHealthEnemyBuffContainer then
        ownPMHContainer(plate.MobHealthEnemyBuffContainer, plate, rowGap(38), 'BUFF')
        claimed = true
    end
    return claimed
end

local function claimGODMODENameplatesUnit(unit)
    if not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return false end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return false end
    return claimGODMODENameplatesPlate(plate)
end

local function scanGODMODENameplates()
    if not isAddonLoadedSafe('GODMODENameplates_Forever') then return 0 end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return 0 end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= 'table' then return 0 end
    local count = 0
    for _, plate in ipairs(plates) do
        if claimGODMODENameplatesPlate(plate) then count = count + 1 end
    end
    return count
end

local nameplateThemeRefreshQueued = false
local function queueNameplateThemeRefresh(delay)
    if nameplateThemeRefreshQueued then return end
    nameplateThemeRefreshQueued = true
    C_Timer.After(tonumber(delay) or 0, function()
        nameplateThemeRefreshQueued = false
        -- GODMODE Nameplates finishes its container scale/layout after the first
        -- cooldown SetCooldown calls during login/reload.  Reapply the saved
        -- Nameplates theme once AFTER that layout settles so a saved font size
        -- (for example 9) is not calculated against a transient early scale.
        -- This is a bounded one-shot refresh, not polling/OnUpdate.
        if Addon.Refresh then Addon:Refresh() end
    end)
end

local function attachGODMODENameplatesCompat()
    if not isAddonLoadedSafe('GODMODENameplates_Forever') then return false end
    local count = scanGODMODENameplates()
    if count > 0 then queueNameplateThemeRefresh(0) end
    return true
end

local function applyNameplateCooldownAppearance(cooldown)
    if not cooldown then return end
    local profile0 = Addon.db and Addon.db.profile
    local theme0 = profile0 and profile0.themes and profile0.themes.nameplates
    if theme0 then
        local sc = theme0.swipeColor
        local sig = table.concat({tostring(theme0.themeCooldown),tostring(theme0.drawSwipe),tostring(theme0.drawEdge),tostring(theme0.drawBling),tostring(theme0.reverse),tostring(theme0.themeSwipeColor),tostring(sc)}, '|')
        if cooldown._ogmNPThemeAppearanceSig == sig then return end
        cooldown._ogmNPThemeAppearanceSig = sig
    end
    local profile = Addon.db and Addon.db.profile
    local theme = profile and profile.themes and profile.themes[(profile.godmodeAutoFitEnabled and 'godmode_autofit') or 'nameplates']
    if not theme then return end
    local function state(value, fallback)
        if value == 'always' then return true end
        if value == 'never' then return false end
        return fallback
    end
    local enabled = theme.themeCooldown ~= false
    if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, enabled and state(theme.drawSwipe, true)) end
    if cooldown.SetDrawEdge then pcall(cooldown.SetDrawEdge, cooldown, enabled and state(theme.drawEdge, true)) end
    if cooldown.SetDrawBling then pcall(cooldown.SetDrawBling, cooldown, enabled and state(theme.drawBling, true)) end
    if cooldown.SetReverse then pcall(cooldown.SetReverse, cooldown, enabled and state(theme.reverse, false)) end
    if cooldown.SetSwipeColor then
        if theme.themeSwipeColor and theme.swipeColor and Addon.HexToRGBA then
            if not cooldown._ogmCustomSwipeApplied and cooldown.GetSwipeColor then
                local ok, r0,g0,b0,a0 = pcall(cooldown.GetSwipeColor, cooldown)
                if ok and type(r0)=='number' and type(g0)=='number' and type(b0)=='number' and type(a0)=='number' then
                    cooldown._ogmOriginalSwipeRGBA = {r0,g0,b0,a0}
                end
            end
            local r,g,b,a = Addon.HexToRGBA(theme.swipeColor)
            pcall(cooldown.SetSwipeColor, cooldown, r,g,b,a)
            cooldown._ogmCustomSwipeApplied = true
        elseif cooldown._ogmCustomSwipeApplied then
            local original = cooldown._ogmOriginalSwipeRGBA
            if original then
                pcall(cooldown.SetSwipeColor, cooldown, original[1], original[2], original[3], original[4])
            end
            cooldown._ogmCustomSwipeApplied = nil
        end
    end
end

local function refreshNameplateThemeAppearance()
    for cd in pairs(ownedCountdowns) do
        applyNameplateCooldownAppearance(cd)
    end
end

local function applyNameplateCountdownFormatter(cooldown)
    if not cooldown then return end
    applyNameplateCooldownAppearance(cooldown)
    if not cooldown.SetCountdownFormatter then return end
    local profile = Addon.db and Addon.db.profile
    local themes = profile and profile.themes
    local actionTheme = themes and themes.nameplates
    if not actionTheme or not Addon.CreateCountdownFormatter then return end
    local colors = actionTheme.textColors
    local colorSig = ''
    if type(colors)=='table' then
        local parts={}
        for k,v in pairs(colors) do
            parts[#parts+1]=tostring(k)..'='..tostring(v)
        end
        table.sort(parts)
        colorSig=table.concat(parts,',')
    else
        colorSig=tostring(colors)
    end
    local fsig = table.concat({tostring(actionTheme.fontSize),tostring(actionTheme.drawText),tostring(actionTheme.minDuration),tostring(actionTheme.abbrevThreshold),tostring(actionTheme.scaleText),tostring(actionTheme.fontFlags),tostring(actionTheme.defaultTextColor),colorSig}, '|')
    Addon._ogmNPFormatterCache = Addon._ogmNPFormatterCache or {}
    local cache = Addon._ogmNPFormatterCache
    local formatter = cache[fsig]
    if not formatter then
        local ok, made = pcall(Addon.CreateCountdownFormatter, Addon, actionTheme)
        if ok and made then formatter=made; cache[fsig]=made end
    end
    if formatter and cooldown._ogmNPFormatterSig ~= fsig then
        pcall(cooldown.SetCountdownFormatter, cooldown, formatter)
        cooldown._ogmNPFormatterSig = fsig
        cooldown._ogmActionColorFormatter = formatter
        cooldown._ogmActionColorSource = actionTheme
    end
end


-- COLOR-ONLY FIX: keep the established GODMODE cooldown FontString so its
-- exact saved size/position/scale remains unchanged. The action-bar formatter
-- below changes only the displayed duration color/format.
local function bindGODMODENameplateDuration(button, cooldown)
    return false
end

-- Independent GODMODE debuff row for Forever/Plater -------------------------
-- 12.1 SAFE ARCHITECTURE: Blizzard's CustomAuraContainerTemplate owns aura
-- discovery and live UNIT_AURA refreshes.  GODMODE owns the visible buttons,
-- layout and cooldown style.  This deliberately does NOT read C_UnitAuras,
-- does NOT read Plater's cache and does NOT scan/re-style plates on UNIT_AURA.
local ownedDebuffRows = {}
local securePool, secureByUnit = {}, {}
local secureByPlate = setmetatable({}, {__mode='k'})
local MAX_SECURE_PLATES = 40
local MAX_OWNED_DEBUFFS = 10

local function ownedAnchor(plate)
    local uf = plate and (plate.unitFrame or plate.UnitFrame)
    return (uf and (uf.healthBar or uf.HealthBar)) or uf or plate
end


-- GODMODE SAFE NAMEPLATE BORDER PAINT ---------------------------------------
-- Initialization-only. Blizzard owns aura assignment/recycling and recolors
-- this registered texture itself. No UNIT_AURA scan, OnUpdate, SetAura hook,
-- or runtime texture creation is used here.
local function ogmInstallNativeHarmfulBorder(button)
    if not button or button._ogmNativeHarmfulBorderInstalled or not button.CreateTexture then return end
    button._ogmNativeHarmfulBorderInstalled=true
    if not button.AddDispelTypeTexture then return end
    local E=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local style=E and (E.Border or E.Overlay)
    if style==nil or type(CreateColor)~='function' then return end
    local border=button:CreateTexture(nil,'OVERLAY',nil,7)
    border:SetPoint('TOPLEFT',button,'TOPLEFT',-2,2)
    border:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',2,-2)
    if border.SetSnapToPixelGrid then pcall(border.SetSnapToPixelGrid,border,true) end
    if border.SetTexelSnappingBias then pcall(border.SetTexelSnappingBias,border,0) end
    local colors={
        Magic=CreateColor(0.20,0.60,1.00,1),
        Poison=CreateColor(0.25,0.85,0.20,1),
        Curse=CreateColor(0.65,0.25,0.85,1),
        Disease=CreateColor(0.80,0.65,0.20,1),
        Bleed=CreateColor(0.95,0.12,0.12,1),
        Enrage=CreateColor(0.95,0.18,0.08,1),
        None=CreateColor(0.95,0.12,0.12,1),
    }
    local ok=pcall(button.AddDispelTypeTexture,button,border,{style=style,showWhenHarmful=true,showWhenHelpful=false,showWithoutDispelType=true,customDispelColorMap=colors})
    if ok then button._ogmNativeHarmfulBorder=border else pcall(border.Hide,border) end
end
local function ogmInstallNativeHelpfulBorder(button)
    if not button or button._ogmNativeHelpfulBorderInstalled or not button.CreateTexture then return end
    button._ogmNativeHelpfulBorderInstalled=true
    if not button.AddDispelTypeTexture then return end
    local E=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local style=E and (E.Border or E.Overlay)
    if style==nil or type(CreateColor)~='function' then return end
    local border=button:CreateTexture(nil,'OVERLAY',nil,7)
    border:SetPoint('TOPLEFT',button,'TOPLEFT',-2,2)
    border:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',2,-2)
    if border.SetSnapToPixelGrid then pcall(border.SetSnapToPixelGrid,border,true) end
    if border.SetTexelSnappingBias then pcall(border.SetTexelSnappingBias,border,0) end
    local green=CreateColor(0.25,0.85,0.20,1)
    local colors={Magic=green,Poison=green,Curse=green,Disease=green,Bleed=green,Enrage=green,None=green}
    local ok=pcall(button.AddDispelTypeTexture,button,border,{style=style,showWhenHarmful=false,showWhenHelpful=true,showWithoutDispelType=true,customDispelColorMap=colors})
    if ok then button._ogmNativeHelpfulBorder=border else pcall(border.Hide,border) end
end
-- End safe border paint ------------------------------------------------------


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

local function initSecureDebuffButton(button)
    local size = 30
    button:SetSize(size,size)
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled,button,false) end
    if button.SetHideTooltipInCombat then pcall(button.SetHideTooltipInCombat,button,true) end
    local icon=button:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('TOPLEFT',button,'TOPLEFT',2,-2); icon:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-2,2); icon:SetTexCoord(.055,.945,.055,.945)
    if icon.SetSnapToPixelGrid then pcall(icon.SetSnapToPixelGrid,icon,true) end
    if icon.SetTexelSnappingBias then pcall(icon.SetTexelSnappingBias,icon,0) end
    button.Icon=icon
    if button.SetIcon then pcall(button.SetIcon,button,icon) end
    ogmBindNativeAuraStacks(button)
    -- GODMODE premium edge: four pixel-aligned strips sit OUTSIDE the artwork,
    -- never across the middle of the spell texture.
    if not button._ogmPremiumEdges and button.CreateTexture then
        local edges={}
        for i=1,4 do
            local e=button:CreateTexture(nil,'OVERLAY',nil,7)
            e:SetColorTexture(0.06,0.06,0.06,1)
            edges[i]=e
        end
        edges[1]:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); edges[1]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); edges[1]:SetHeight(2)
        edges[2]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); edges[2]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); edges[2]:SetHeight(2)
        edges[3]:SetPoint('TOPLEFT',button,'TOPLEFT',0,-2); edges[3]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,2); edges[3]:SetWidth(2)
        edges[4]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,-2); edges[4]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,2); edges[4]:SetWidth(2)
        button._ogmPremiumEdges=edges
    end
    ogmInstallNativeHarmfulBorder(button)
    -- Native Blizzard border is the single harmful border owner. Keep the old
    -- premium strips from competing with it during AuraContainer reassignment.
    if button._ogmPremiumEdges then
        for i=1,4 do local e=button._ogmPremiumEdges[i]; if e and e.SetAlpha then pcall(e.SetAlpha,e,0) end end
    end
    -- v19: keep the secure AuraButton visually clean.  Do not attach custom
    -- border/glow textures here: Forever can apply protected aura-button scaling
    -- after initializeFrame, which caused those textures to stretch across the UI.
    -- The Blizzard-owned icon/cooldown remains the complete visual surface.
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button); cd:EnableMouse(false)
    cd.OGMGodmodeNameplateCooldown=true; cd.OGMNameplateAura=true; ownedCountdowns[cd]=true; cd.OGMNameplateAuraKind='DEBUFF'; cd._ogmCompatScope='nameplates'
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,false) end
    -- v26: keep spell artwork fully visible. The cooldown swipe was darkening the
    -- icon heavily while a debuff was active; GODMODE only needs the countdown text.
    applyNameplateCooldownAppearance(cd)
    if cd.SetCountdownAbbrevThreshold then pcall(cd.SetCountdownAbbrevThreshold,cd,60) end
    if cd.SetMinimumCountdownDuration then pcall(cd.SetMinimumCountdownDuration,cd,0) end
    button.Cooldown=cd
    if button.SetDurationCooldown then pcall(button.SetDurationCooldown,button,cd) end
    if hooksecurefunc and cd.SetCooldown and not cd._ogmTextSizeHooked then
        cd._ogmTextSizeHooked=true
        hooksecurefunc(cd,'SetCooldown',function(self) styleCountdownFontString(self, true) end)
    end
    applyNameplateCountdownTextStyle(button)
    -- Coalesce next-frame native formatter corrections per aura button. Recycled
    -- nameplate buttons can be initialized more than once in one camera burst;
    -- never enqueue multiple redundant style passes for the same button.
    if C_Timer and C_Timer.After and not button._ogmStylePending then
        button._ogmStylePending = true
        C_Timer.After(0, function()
            button._ogmStylePending = nil
            if button and button.Cooldown then applyNameplateCountdownTextStyle(button) end
        end)
    end
    -- One secure renderer only. Prefer AuraButton:SetDurationText because it owns
    -- both the protected remaining-time value and the native color curve. Fall
    -- back to the old Cooldown formatter only if this client rejects the binding.
    if not bindGODMODENameplateDuration(button,cd) then
        applyNameplateCountdownFormatter(cd)
        if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,false) end
        -- AuraContainer can finish its own formatter setup after initializeFrame.
        -- Re-assert COLOR ONLY once on the next frame; never touch font/size/scale.
        if C_Timer and C_Timer.After and not cd._ogmFormatterPending then
            cd._ogmFormatterPending = true
            C_Timer.After(0,function()
                cd._ogmFormatterPending = nil
                if cd and cd.GetParent then applyNameplateCountdownFormatter(cd) end
            end)
        end
    end
end

local function getNormalDebuffFilterString()
    -- CC is deliberately handled by its own group and remains visible from
    -- everyone.  Only the normal DoT/debuff group changes source ownership.
    if db.showAllDebuffs == false then
        return 'HARMFUL|PLAYER|!CROWD_CONTROL'
    end
    -- ALL AURAS means exactly that: every readable harmful aura on the NPC.
    -- Do not require INCLUDE_NAME_PLATE_ONLY; many real debuffs/DoTs/roots are
    -- intentionally omitted from Blizzard's native nameplate-only candidate set.
    return 'HARMFUL|!CROWD_CONTROL'
end

local function configureSecureContainer(c)
    -- Match the working Forever Threat Plates AuraContainer lifecycle: create
    -- the group once, then configure it through Blizzard's live group setters.
    -- The old nested candidateFilters table was invalid for the 1.60.1 API.
    local layout={elementWidth=30,elementHeight=30,elementSpacing=3,lineSpacing=0}
    -- v27: two mutually-exclusive harmful groups.  The normal nameplate group
    -- accepts auras from ANY source (not only the local player), while CC gets
    -- its own Blizzard CROWD_CONTROL group so roots/stuns/fears/charms are not
    -- lost just because they are not tagged INCLUDE_NAME_PLATE_ONLY.
    local ok=pcall(c.AddAuraGroup,c,'ogm_np_harmful','HARMFUL',{
        initializeFrame=initSecureDebuffButton,
    })
    if not ok then return false end
    local okCC=pcall(c.AddAuraGroup,c,'ogm_np_cc','HARMFUL',{
        initializeFrame=initSecureDebuffButton,
    })
    if not okCC then return false end
    -- Friendly-player groups are kept in the same preallocated secure container.
    -- They are enabled only while the container is bound to a friendly unit, so
    -- enemy/NPC behavior remains byte-for-byte equivalent at runtime.
    pcall(c.AddAuraGroup,c,'ogm_np_friendly_hots','HELPFUL',{ initializeFrame=initSecureDebuffButton })
    pcall(c.AddAuraGroup,c,'ogm_np_friendly_buffs','HELPFUL',{ initializeFrame=initSecureDebuffButton })
    pcall(c.AddAuraGroup,c,'ogm_np_friendly_debuffs','HARMFUL',{ initializeFrame=initSecureDebuffButton })
    if c.SetAuraGroupFilterString then
        local sourceFilter = getNormalDebuffFilterString()
        if pcall(c.SetAuraGroupFilterString,c,'ogm_np_harmful',sourceFilter) then
            c._ogmAppliedSourceFilter = sourceFilter
        end
        pcall(c.SetAuraGroupFilterString,c,'ogm_np_cc','HARMFUL|CROWD_CONTROL')
        -- HoTs/nameplate-helpful effects first; ordinary player-cast buffs use the
        -- complementary group. Blizzard performs the aura classification.
        -- Forever 1.60.1 does not reliably honor !INCLUDE_NAME_PLATE_ONLY.
        -- Using two HELPFUL groups therefore rendered the same HoT/buff twice.
        -- One Blizzard HELPFUL|PLAYER group is the single friendly helpful source.
        pcall(c.SetAuraGroupFilterString,c,'ogm_np_friendly_hots','HELPFUL|PLAYER')
        pcall(c.SetAuraGroupFilterString,c,'ogm_np_friendly_buffs','HELPFUL|PLAYER')
        pcall(c.SetAuraGroupFilterString,c,'ogm_np_friendly_debuffs','HARMFUL|RAID')
    end
    if c.SetAuraGroupCandidateFilters then
        pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_harmful',{})
        pcall(c.SetAuraGroupCandidateFilters,c,'ogm_np_cc',{})
    end
    applyExactCustomCandidates(c)
    if c.SetAuraGroupMaxFrameCount then
        pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_np_harmful',MAX_OWNED_DEBUFFS)
        pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_np_cc',0) -- switched live by updateOwnedDebuffRow
        -- Start friendly groups disabled; binding decides which side owns the row.
        pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_np_friendly_hots',0)
        pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_np_friendly_buffs',0)
        pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_np_friendly_debuffs',0)
    end
    if c.SetAuraGroupLayout then
        pcall(c.SetAuraGroupLayout,c,'ogm_np_harmful',layout)
        pcall(c.SetAuraGroupLayout,c,'ogm_np_cc',layout)
    end
    local FD=AnchorUtil and AnchorUtil.FlowDirection
    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPLEFT') end
    if c.SetFlowLayoutGrowthDirection and FD and FD.Right and FD.Down then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,FD.Down) end
    if c.SetFlowLayoutMaximumLineSize then pcall(c.SetFlowLayoutMaximumLineSize,c,400) end
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    return true
end

local function preallocateSecureRows()
    if #securePool>0 then return end
    if not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo('CustomAuraContainerTemplate') then return end
    for i=1,MAX_SECURE_PLATES do
        local ok,c=pcall(CreateFrame,'AuraContainer','OmniCC_GODMODE_NameplateAura'..i,UIParent,'CustomAuraContainerTemplate')
        if ok and c then
            c:SetSize(400,30); c:Hide(); c._ogmUnit=nil
            if configureSecureContainer(c) then securePool[#securePool+1]=c end
        end
    end
end

-- GODMODE THREE-LANE NAMEPLATE AURAS ----------------------------------------
-- TOP = normal DoTs/debuffs (the existing owned container)
-- LEFT = friendly HoTs/buffs
-- RIGHT = important crowd-control effects
-- Separate Blizzard AuraContainers keep the lanes independent without scanning
-- aura data in addon code; Blizzard remains the live UNIT_AURA owner.
local sideLaneByPlate = setmetatable({}, {__mode='k'})
local sideLanePool = {}
local function initLaneButton(button)
    local size=30
    button:SetSize(size,size)
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled,button,false) end
    if button.SetHideTooltipInCombat then pcall(button.SetHideTooltipInCombat,button,true) end
    local icon=button:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('TOPLEFT',button,'TOPLEFT',2,-2); icon:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',-2,2); icon:SetTexCoord(.055,.945,.055,.945)
    if icon.SetSnapToPixelGrid then pcall(icon.SetSnapToPixelGrid,icon,true) end
    if icon.SetTexelSnappingBias then pcall(icon.SetTexelSnappingBias,icon,0) end
    button.Icon=icon
    if button.SetIcon then pcall(button.SetIcon,button,icon) end
    ogmBindNativeAuraStacks(button)
    -- GODMODE premium edge: four pixel-aligned strips sit OUTSIDE the artwork,
    -- never across the middle of the spell texture.
    if not button._ogmPremiumEdges and button.CreateTexture then
        local edges={}
        for i=1,4 do
            local e=button:CreateTexture(nil,'OVERLAY',nil,7)
            e:SetColorTexture(0.06,0.06,0.06,1)
            edges[i]=e
        end
        edges[1]:SetPoint('TOPLEFT',button,'TOPLEFT',0,0); edges[1]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,0); edges[1]:SetHeight(2)
        edges[2]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,0); edges[2]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,0); edges[2]:SetHeight(2)
        edges[3]:SetPoint('TOPLEFT',button,'TOPLEFT',0,-2); edges[3]:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT',0,2); edges[3]:SetWidth(2)
        edges[4]:SetPoint('TOPRIGHT',button,'TOPRIGHT',0,-2); edges[4]:SetPoint('BOTTOMRIGHT',button,'BOTTOMRIGHT',0,2); edges[4]:SetWidth(2)
        button._ogmPremiumEdges=edges
    end
    ogmInstallNativeHarmfulBorder(button)
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button); cd:EnableMouse(false)
    cd.OGMGodmodeNameplateCooldown=true; cd.OGMNameplateAura=true; ownedCountdowns[cd]=true; cd._ogmCompatScope='nameplates'
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,false) end
    applyNameplateCooldownAppearance(cd)
    if cd.SetCountdownAbbrevThreshold then pcall(cd.SetCountdownAbbrevThreshold,cd,60) end
    if cd.SetMinimumCountdownDuration then pcall(cd.SetMinimumCountdownDuration,cd,0) end
    button.Cooldown=cd
    if button.SetDurationCooldown then pcall(button.SetDurationCooldown,button,cd) end
    if hooksecurefunc and cd.SetCooldown and not cd._ogmTextSizeHooked then
        cd._ogmTextSizeHooked=true
        hooksecurefunc(cd,'SetCooldown',function(self) styleCountdownFontString(self, true) end)
    end
    applyNameplateCountdownTextStyle(button)
    -- Coalesce next-frame native formatter corrections per aura button. Recycled
    -- nameplate buttons can be initialized more than once in one camera burst;
    -- never enqueue multiple redundant style passes for the same button.
    if C_Timer and C_Timer.After and not button._ogmStylePending then
        button._ogmStylePending = true
        C_Timer.After(0, function()
            button._ogmStylePending = nil
            if button and button.Cooldown then applyNameplateCountdownTextStyle(button) end
        end)
    end
    -- One secure renderer only. Prefer AuraButton:SetDurationText because it owns
    -- both the protected remaining-time value and the native color curve. Fall
    -- back to the old Cooldown formatter only if this client rejects the binding.
    if not bindGODMODENameplateDuration(button,cd) then
        applyNameplateCountdownFormatter(cd)
        if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,false) end
        -- AuraContainer can finish its own formatter setup after initializeFrame.
        -- Re-assert COLOR ONLY once on the next frame; never touch font/size/scale.
        if C_Timer and C_Timer.After and not cd._ogmFormatterPending then
            cd._ogmFormatterPending = true
            C_Timer.After(0,function()
                cd._ogmFormatterPending = nil
                if cd and cd.GetParent then applyNameplateCountdownFormatter(cd) end
            end)
        end
    end
end
local function initLaneHelpfulHotButton(button)
    initLaneButton(button)
    ogmInstallNativeHelpfulBorder(button)
    if button and button._ogmPremiumEdges then for i=1,4 do local e=button._ogmPremiumEdges[i]; if e and e.SetAlpha then pcall(e.SetAlpha,e,0) end end end
end
local function initLaneHelpfulBuffButton(button)
    initLaneButton(button)
    ogmInstallNativeHelpfulBorder(button)
    if button and button._ogmPremiumEdges then for i=1,4 do local e=button._ogmPremiumEdges[i]; if e and e.SetAlpha then pcall(e.SetAlpha,e,0) end end end
end
local function initLaneHarmfulButton(button)
    initLaneButton(button)
    -- Harmful lanes use Blizzard's registered native border only. Removing the
    -- competing dark strips prevents the visible border from blinking beneath them.
    if button and button._ogmPremiumEdges then
        for i=1,4 do local e=button._ogmPremiumEdges[i]; if e and e.SetAlpha then pcall(e.SetAlpha,e,0) end end
    end
end

local FRIENDLY_HOT_SPELLS = {[774]=true,[1058]=true,[1430]=true,[2090]=true,[2091]=true,[3627]=true,[8910]=true,[9839]=true,[9840]=true,[9841]=true,[417065]=true,[8936]=true,[8938]=true,[8939]=true,[8940]=true,[8941]=true,[9750]=true,[9856]=true,[9857]=true,[9858]=true,[33763]=true,[48438]=true,[155777]=true,[188550]=true,[61295]=true,[974]=true,[119611]=true,[124682]=true,[191840]=true,[139]=true,[6074]=true,[6075]=true,[6076]=true,[6077]=true,[6078]=true,[10927]=true,[10928]=true,[10929]=true,[41635]=true,[17]=true,[194384]=true,[53563]=true,[156322]=true,[366155]=true,[367364]=true,[383648]=true,[410089]=true,[115175]=true,[22842]=true,[355941]=true,[363502]=true,[364343]=true,[373267]=true,[376788]=true,[360827]=true,[395152]=true,[410263]=true,[410686]=true,[413984]=true,[77489]=true,[1253593]=true,[450769]=true,[156910]=true,[1244893]=true}
local function newLane(kind,index)
    local ok,c=pcall(CreateFrame,'AuraContainer','OmniCC_GODMODE_Nameplate'..kind..index,UIParent,'CustomAuraContainerTemplate')
    if not ok or not c then return nil end
    c:SetSize(220,30); c:Hide(); c._ogmLaneKind=kind
    if kind=='CC' then
        local group='ogm_lane_CC'
        if not pcall(c.AddAuraGroup,c,group,'HARMFUL',{maxFrameCount=1,candidateFilters={},initializeFrame=initLaneHarmfulButton}) then return nil end
        if c.SetAuraGroupFilterString then pcall(c.SetAuraGroupFilterString,c,group,'HARMFUL|CROWD_CONTROL') end
        if c.SetAuraGroupMaxFrameCount then pcall(c.SetAuraGroupMaxFrameCount,c,group,1) end
        if c.SetAuraGroupLayout then pcall(c.SetAuraGroupLayout,c,group,{elementWidth=30,elementHeight=30,elementSpacing=3,lineSpacing=0}) end
    else
        -- One LEFT AuraContainer, three independent groups. HoTs are the known
        -- healing-over-time spell set; Buffs explicitly EXCLUDE that set, so the
        -- two switches can never reveal/hide each other's category. Friendly
        -- debuffs are a third HARMFUL|RAID group controlled independently.
        local common={layout={elementWidth=30,elementHeight=30,elementSpacing=3,lineSpacing=0}}
        local function add(group,filter,candidates,initializer)
            local opts={maxFrameCount=6,candidateFilters=candidates or {},initializeFrame=initializer or initLaneHarmfulButton,layout=common.layout}
            if not pcall(c.AddAuraGroup,c,group,filter,opts) then return false end
            if c.SetAuraGroupFilterString then pcall(c.SetAuraGroupFilterString,c,group,filter) end
            if c.SetAuraGroupCandidateFilters then pcall(c.SetAuraGroupCandidateFilters,c,group,candidates or {}) end
            if c.SetAuraGroupLayout then pcall(c.SetAuraGroupLayout,c,group,common.layout) end
            return true
        end
        -- Forever 1.60.1 does not reliably honor include/exclude candidate filters
        -- for secure HELPFUL nameplate groups. Two HELPFUL groups therefore become
        -- two renderers for the same aura. Use ONE authoritative HELPFUL group.
        -- The legacy HoT/Buff toggles both control this single friendly-helpful lane.
        if not add('ogm_lane_HELPFUL','HELPFUL|PLAYER',{},initLaneHelpfulHotButton) then return nil end
        -- RAID is too restrictive here (it can omit visible friendly-player debuffs).
        -- Let Blizzard's secure AuraContainer own all HARMFUL discovery instead.
        if not add('ogm_lane_DEBUFFS','HARMFUL',{}) then return nil end
    end
    if c.SetFlowLayoutMaximumLineSize then pcall(c.SetFlowLayoutMaximumLineSize,c,220) end
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    return c
end
local function preallocateSideLanes()
    if #sideLanePool>0 or not C_XMLUtil or not C_XMLUtil.GetTemplateInfo or not C_XMLUtil.GetTemplateInfo('CustomAuraContainerTemplate') then return end
    for i=1,MAX_SECURE_PLATES do
        local cc=newLane('CC',i); local help=newLane('HELP',i)
        if cc and help then sideLanePool[#sideLanePool+1]={cc=cc,help=help,_plate=nil} end
    end
end
preallocateSideLanes()
local function laneBundle(plate)
    local b=sideLaneByPlate[plate]
    if b then return b end
    for _,v in ipairs(sideLanePool) do if not v._plate then v._plate=plate; sideLaneByPlate[plate]=v; return v end end
end
local function disableLane(c)
    if not c then return end
    -- A plate refresh often visits the inactive opposite-side lane. Avoid
    -- repeatedly invoking native SetEnabled/SetUnit/Hide for an idle lane:
    -- these calls can invalidate Blizzard aura state even when already empty.
    -- Newly created lanes start disabled and unbound in newLane().
    if not c._ogmBoundUnit and not c._ogmLaneActivated then return end
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    if c.SetUnit then pcall(c.SetUnit,c,nil) end
    c._ogmBoundUnit=nil; c._ogmLaneActivated=nil
    pcall(c.Hide,c)
end
local function bindLane(c,unit,anchor,side)
    if not c or not unit or not anchor then return end
    if c._ogmBoundUnit~=unit then
        c._ogmLaneActivated=nil
        if c.SetEnabled then pcall(c.SetEnabled,c,false) end
        if c.SetUnit then pcall(c.SetUnit,c,nil); pcall(c.SetUnit,c,unit) end
        c._ogmBoundUnit=unit
        -- SetUnit() schedules/populates the secure AuraContainer itself.
        -- Do not force a second synchronous UpdateAllAuras during camera plate churn.
    end
    -- Reapply lane layout only when the physical anchor or side changes.
    -- The AuraContainer follows its anchor automatically as the camera moves.
    local layoutChanged = c._ogmLaneAnchor ~= anchor or c._ogmLaneSide ~= side
    if layoutChanged then
        pcall(c.ClearAllPoints,c)
    end
    local FD=AnchorUtil and AnchorUtil.FlowDirection
    if layoutChanged and side=='RIGHT' then
        pcall(c.SetPoint,c,'LEFT',anchor,'RIGHT',5,0)
        if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPLEFT') end
        if c.SetFlowLayoutGrowthDirection and FD and FD.Right and FD.Down then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,FD.Down) end
    elseif layoutChanged then
        -- Friendly HELP/buff lane stays physically attached to the nameplate
        -- health bar, but starts a little farther right than the old -5 gap.
        -- A small +4 inset keeps the first icon visually close to the bar while
        -- still growing LEFT, so it follows nameplate movement/resizing exactly.
        pcall(c.SetPoint,c,'RIGHT',anchor,'LEFT',-5,0)
        if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPRIGHT') end
        if c.SetFlowLayoutGrowthDirection and FD and FD.Left and FD.Down then pcall(c.SetFlowLayoutGrowthDirection,c,FD.Left,FD.Down) end
    end
    if layoutChanged then
        c._ogmLaneAnchor = anchor
        c._ogmLaneSide = side
    end
    local desiredScale=getQuickContainerScale()
    -- Only the RIGHT CC lane receives independent sizing. TOP CC remains in
    -- the ordinary nameplate aura row, using its normal icon size.
    if side == 'RIGHT' and c._ogmLaneKind == 'CC' then
        desiredScale = desiredScale * (math.max(16,math.min(64,tonumber(db.ccRightSize) or 30)) / 30)
    end
    if c._ogmAppliedLaneScale ~= desiredScale then
        pcall(c.SetScale,c,desiredScale)
        c._ogmAppliedLaneScale=desiredScale
    end
    -- The native AuraContainer owns live UNIT_AURA processing. Re-enabling an
    -- unchanged lane on every plate refresh is redundant and can rebuild auras.
    -- A failed operation is never cached as success.
    if not c._ogmLaneActivated then
        local okEnabled = not c.SetEnabled or pcall(c.SetEnabled,c,true)
        local okShown = okEnabled and pcall(c.Show,c)
        if okEnabled and okShown then c._ogmLaneActivated=true end
    end
    -- PERF: Do not recursively traverse the entire aura frame hierarchy on
    -- nameplate entry or lane repositioning. Existing per-button hooks style
    -- new cooldowns; explicit theme refreshes retain their full styling pass.
end
-- Immutable candidate configurations: reuse across plate bindings rather than
-- allocating a new table for each friendly aura reconciliation.
local FRIENDLY_ALL_CANDIDATES = {}
local FRIENDLY_HOT_ONLY_CANDIDATES = {includeSpellIDs=FRIENDLY_HOT_SPELLS}
local FRIENDLY_NON_HOT_CANDIDATES = {excludeSpellIDs=FRIENDLY_HOT_SPELLS}
local function updateSideLanes(unit,plate,knownFriendly)
    -- PERF: do not reserve or initialize two Blizzard AuraContainers on an
    -- enemy plate when its separate CC lane is disabled.  A native aura row
    -- still handles ordinary debuffs; no additional lane is required.
    local friendly = knownFriendly
    if friendly == nil then friendly = UnitIsFriend('player',unit) and true or false end
    if not friendly and db.ccPlacement == 'TOP' then
        local existing = plate and sideLaneByPlate[plate]
        if existing then disableLane(existing.cc); disableLane(existing.help); existing._plate=nil; sideLaneByPlate[plate]=nil end
        return
    end
    if friendly and db.friendlyHots == false and db.friendlyBuffs == false and db.friendlyDebuffs == false then
        local existing = plate and sideLaneByPlate[plate]
        if existing then disableLane(existing.cc); disableLane(existing.help); existing._plate=nil; sideLaneByPlate[plate]=nil end
        return
    end
    local b=plate and laneBundle(plate); if not b then return end
    local anchor=ownedAnchor(plate); if not anchor then disableLane(b.cc); disableLane(b.help); return end
    if friendly then
        disableLane(b.cc)
        local hotsOn=db.friendlyHots ~= false
        local buffsOn=db.friendlyBuffs ~= false
        local debuffsOn=db.friendlyDebuffs ~= false
        if b.help and b.help.SetAuraGroupMaxFrameCount then
            -- Forever must keep ONE HELPFUL renderer (two HELPFUL groups duplicate icons).
            -- Change only that group's candidate set so HoTs and ordinary Buffs remain
            -- independent while still using the same secure renderer.
            -- PERF: the friendly candidate mode is configuration, not live aura
            -- data. Build no temporary candidate tables on unchanged bindings.
            -- These immutable filter tables are safe for Blizzard to retain.
            local candidateMode = (hotsOn and not buffsOn) and 1 or ((buffsOn and not hotsOn) and 2 or 0)
            if b.help.SetAuraGroupCandidateFilters and b.help._ogmFriendlyCandidateMode ~= candidateMode then
                local candidates = candidateMode == 1 and FRIENDLY_HOT_ONLY_CANDIDATES
                    or candidateMode == 2 and FRIENDLY_NON_HOT_CANDIDATES
                    or FRIENDLY_ALL_CANDIDATES
                local ok = pcall(b.help.SetAuraGroupCandidateFilters,b.help,'ogm_lane_HELPFUL',candidates)
                if ok then b.help._ogmFriendlyCandidateMode = candidateMode end
            end
            -- Avoid repeatedly invalidating secure friendly aura groups when their
            -- configured capacity has not changed.  Do not cache failed calls.
            local helpfulCount = (hotsOn or buffsOn) and 6 or 0
            local debuffCount = debuffsOn and 6 or 0
            if b.help._ogmFriendlyHelpfulCount ~= helpfulCount then
                local ok = pcall(b.help.SetAuraGroupMaxFrameCount,b.help,'ogm_lane_HELPFUL',helpfulCount)
                if ok then b.help._ogmFriendlyHelpfulCount = helpfulCount end
            end
            if b.help._ogmFriendlyDebuffCount ~= debuffCount then
                local ok = pcall(b.help.SetAuraGroupMaxFrameCount,b.help,'ogm_lane_DEBUFFS',debuffCount)
                if ok then b.help._ogmFriendlyDebuffCount = debuffCount end
            end
        end
        if hotsOn or buffsOn or debuffsOn then
            -- Keep the already-bound friendly HELP container alive when one category
            -- changes.  UpdateAllAuras() rebuilds *all* three groups on Forever 70170,
            -- making unrelated Buffs disappear for several seconds when only HoTs are
            -- toggled.  MaxFrameCount changes are applied to the live groups directly;
            -- Blizzard's normal UNIT_AURA pass updates only the affected category.
            bindLane(b.help,unit,anchor,'LEFT')
        else
            disableLane(b.help)
        end
    else
        disableLane(b.help)
        local customCCAny = applyExactCustomLaneCandidates(b.cc)
        if db.ccPlacement == 'TOP' or not customCCAny then
            disableLane(b.cc)
        else
            bindLane(b.cc,unit,anchor,'RIGHT')
        end
    end
end
local function releaseSideLanes(plate)
    local b=plate and sideLaneByPlate[plate]; if not b then return end
    disableLane(b.cc); disableLane(b.help); b._plate=nil; sideLaneByPlate[plate]=nil
end
preallocateSecureRows()

applyDebuffSourceMode = function()
    local filter = getNormalDebuffFilterString()
    for _, c in ipairs(securePool) do
        if c and c.SetAuraGroupFilterString and c._ogmAppliedSourceFilter ~= filter then
            -- A settings toggle changes this secure filter once per container.
            -- Do not rebuild an unchanged group or refresh unbound pooled rows.
            local ok = pcall(c.SetAuraGroupFilterString,c,'ogm_np_harmful',filter)
            if ok then
                c._ogmAppliedSourceFilter = filter
                -- Blizzard continues to own all subsequent per-unit UNIT_AURA updates.
                if c._ogmBoundUnit and c.UpdateAllAuras then pcall(c.UpdateAllAuras,c) end
            end
        end
    end
end

local function acquireSecureRow(unit,plate)
    -- v26: mirror the stable Threat Plates lifecycle: an AuraContainer is assigned
    -- to one physical nameplate frame for the lifetime of that frame. Do NOT return
    -- it to a global unit-token pool and hand it to another plate. Forever recycles
    -- nameplate unit tokens aggressively and the generated AuraButtons can retain
    -- the previous binding for a frame or two, which caused phantom/wrong/duplicate
    -- icons on untouched mobs.
    local c = plate and secureByPlate[plate] or nil
    if not c then
        for _,candidate in ipairs(securePool) do
            if not candidate._ogmPlate then c=candidate break end
        end
        if not c then return nil end
        c._ogmPlate=plate
        secureByPlate[plate]=c
    end
    -- A unit token can move to another physical plate. Remove any stale token map
    -- before this plate becomes the authoritative owner.
    local oldForUnit=secureByUnit[unit]
    if oldForUnit and oldForUnit ~= c then
        if oldForUnit.SetEnabled then pcall(oldForUnit.SetEnabled,oldForUnit,false) end
        if oldForUnit.SetUnit then pcall(oldForUnit.SetUnit,oldForUnit,nil) end
        oldForUnit._ogmPrimaryActivated=nil
        oldForUnit._ogmUnit=nil; oldForUnit._ogmBoundUnit=nil; oldForUnit._ogmBoundGUID=nil
        pcall(oldForUnit.Hide,oldForUnit)
    end
    c._ogmUnit=unit
    secureByUnit[unit]=c
    -- PERF: The caller updateOwnedDebuffRow positions and scales this same
    -- container immediately after acquireSecureRow. Avoid performing that
    -- identical secure layout work twice per nameplate bind.
    local okLevel,level=levelSource and pcall(levelSource.GetFrameLevel,levelSource)
    level = okLevel and safeNumber(level) or nil
    -- A recycled plate may be revisited without changing its frame level.
    -- Avoid invoking SetFrameLevel (and its dependent frame propagation) again.
    if level then
        local desiredLevel = level + 40
        if c._ogmAppliedFrameLevel ~= desiredLevel then
            local ok = pcall(c.SetFrameLevel,c,desiredLevel)
            if ok then c._ogmAppliedFrameLevel = desiredLevel end
        end
    end
    return c
end

-- Camera/churn performance guard -------------------------------------------------
-- Nameplates are aggressively recycled while turning the camera.  A synchronous
-- UpdateAllAuras() on every new GUID can make dozens of full Blizzard aura-container
-- rebuilds land in the same frame.  Queue only the initial population and drain it
-- in a tiny budget.  Recycled/removed rows are validated again before any work.
-- SetUnit(unit) already initiates the native AuraContainer population.
-- The previous delayed queue never ran UpdateAllAuras: _ogmBoundGUID was
-- deliberately nil on secure binds and the queued GUID was nil too, but its
-- repeated timers and queue allocations still ran during camera plate churn.
-- Keep the cancellation entry point for the existing teardown lifecycle.
local function cancelInitialAuraPopulate(c)
    -- No separate initial population is queued.
end

local function hideOwnedDebuffRow(unit)
    local c=secureByUnit[unit]
    if c then
        if c._ogmPlate then
            local b=sideLaneByPlate[c._ogmPlate]
            if b then disableLane(b.cc); disableLane(b.help) end
        end
        c._ogmPrimaryActivated=nil
        if c.SetEnabled then pcall(c.SetEnabled,c,false) end; c:Hide()
    end
end

-- Stable helper: avoids creating one closure per NPC binding/refresh.
-- The cache remains owned by the individual Blizzard container.
local function setOwnedGroupCountIfChanged(c, group, count)
    if not c.SetAuraGroupMaxFrameCount then return end
    local cached = c._ogmAppliedGroupCounts
    if not cached then cached = {}; c._ogmAppliedGroupCounts = cached end
    if cached[group] == count then return end
    local ok = pcall(c.SetAuraGroupMaxFrameCount, c, group, count)
    if ok then cached[group] = count end
end

    -- Optional nested timings; no clock calls or allocations when profiling is OFF.
local function npStepStart()
        if OGM_NP_DIAG.enabled and type(debugprofilestop)=='function' then return debugprofilestop() end
    end
local function npStepEnd(key, t)
        if not t then return end
        local elapsed=debugprofilestop()-t
        local k='Forever.step.'..key
        local st=OGM_NP_DIAG.stats[k]
        if not st then st={count=0,total=0,max=0}; OGM_NP_DIAG.stats[k]=st end
        st.count=st.count+1; st.total=st.total+elapsed
        if elapsed>st.max then st.max=elapsed end
    end

updateOwnedDebuffRow = function(unit,plate)
    if not unit or not UnitExists(unit) or (Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates')) or (Addon.ForeverNameplates and Addon.ForeverNameplates._compatSuspended) or db.enabled==false then
        hideOwnedDebuffRow(unit); return
    end
    local isFriendly = UnitIsFriend('player',unit) and true or false
    -- Forever's stock friendly row is not guaranteed to exist on every plate/theme.
    -- Keep GODMODE's secure HELPFUL renderer for friendly players, but place it in
    -- the exact old left-side slot. This also keeps the existing OmniCC text controls.
    if db.targetOnly == true and (not UnitExists('target') or not UnitIsUnit(unit,'target')) then
        hideOwnedDebuffRow(unit); return
    end
    plate=plate or (C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit))
    if not plate then hideOwnedDebuffRow(unit); return end

    -- PERFORMANCE: friendly players use ONLY the dedicated LEFT helpful/debuff lane.
    -- Do not bind a second primary harmful AuraContainer whose groups are all set to 0.
    -- In crowded cities this previously doubled secure AuraContainer work per friendly
    -- nameplate and made camera turns scale badly with the number of visible players.
    if isFriendly then
        local old = secureByUnit[unit]
        if old then releaseOwnedDebuffRow(unit) end
        updateSideLanes(unit,plate,isFriendly)
        return
    end

        local _npAcquire=npStepStart()
    local c=acquireSecureRow(unit,plate); if not c then return end
    npStepEnd('acquire',_npAcquire)
    -- No side-lane work for ordinary enemy debuffs when CC uses the top row.
    -- Existing lanes must still be released if the setting changed.
    if db.ccPlacement ~= 'TOP' or (plate and sideLaneByPlate[plate]) then
        local _npSide=npStepStart()
        updateSideLanes(unit,plate,isFriendly)
        npStepEnd('side_lanes',_npSide)
    end
    -- Switch the already-created secure groups by count; never inspect aura data.
    -- This is safe with Forever secret auras and restores friendly-player HoTs,
    -- buffs and debuffs without changing the enemy/NPC renderer.
    -- Only invoke Blizzard's secure count setter when its effective value changes.
    -- Calling it repeatedly can invalidate/rebuild aura groups on crowded plates.
    -- Reuse the module-level helper; never allocate a new closure for each plate.

    local _npGroups=npStepStart()
    if c.SetAuraGroupMaxFrameCount then
        local _npCandidates=npStepStart()
        local customAny, customCCAny = applyExactCustomCandidates(c)
        npStepEnd('candidates',_npCandidates)
        setOwnedGroupCountIfChanged(c, 'ogm_np_harmful',(isFriendly or not customAny) and 0 or MAX_OWNED_DEBUFFS)
        -- CC has one authoritative renderer: the dedicated RIGHT lane.
        -- Never re-enable the legacy top-row CC group or roots/stuns/fears are duplicated.
        setOwnedGroupCountIfChanged(c, 'ogm_np_cc',(not isFriendly and customCCAny and db.ccPlacement == 'TOP') and 6 or 0)
        -- SINGLE friendly helpful renderer. The previous HOT + BUFF groups overlap on
        -- Forever and duplicate the same aura. Keep the legacy two toggles saved, but
        -- either one enables this one Blizzard helpful row; never render a second copy.
        local showFriendlyHelpful = isFriendly and (db.friendlyHots ~= false or db.friendlyBuffs ~= false)
        setOwnedGroupCountIfChanged(c, 'ogm_np_friendly_hots',0) -- dedicated LEFT lane
        setOwnedGroupCountIfChanged(c, 'ogm_np_friendly_buffs',0)
        setOwnedGroupCountIfChanged(c, 'ogm_np_friendly_debuffs',0)
        npStepEnd('group_setters',_npGroups)
    end
    -- v25: NEVER hide/show an already-bound live AuraContainer on UNIT_AURA.
    -- Forever updates these generated buttons asynchronously. Interrupting that
    -- lifecycle on every Moonfire/Roar change produced a 1-2 second duplicate,
    -- wrong icon, or black icon before Blizzard's next internal pass corrected it.
    -- Only hide the row when its actual unit/GUID identity changes.
    -- v23: do NOT re-bind the same CustomAuraContainer on every refresh.
    -- Forever's AuraContainer can briefly retain the old generated button set
    -- while SetUnit rebuilds the same unit, producing a duplicate/wrong icon
    -- until the next UNIT_AURA pass. Bind only when this pooled row actually
    -- changes units; normal aura changes are owned by Blizzard's live container.
    -- Nameplate unit tokens are recycled (for example, nameplate1 can point to
    -- a completely different mob a moment later). Comparing only the token is
    -- therefore not enough: v23 could keep the previous mob's generated aura
    -- buttons when Blizzard reused the same token. Track the GUID identity too
    -- and force a clean unbind/rebind whenever that identity changes.
    -- Forever can return UnitGUID() as a secret string. Secret values must never
    -- be compared/stored by addon code, because comparing them taints execution.
    -- NAME_PLATE_UNIT_REMOVED already tears this row down when Blizzard recycles
    -- a nameplate, so the non-secret unit-token binding is the safe identity here.
    local _npNative=npStepStart()
    if c._ogmBoundUnit ~= unit then
        c._ogmPrimaryActivated=nil
        pcall(c.Hide,c)
        if c.SetEnabled then pcall(c.SetEnabled,c,false) end
        if c.SetUnit then pcall(c.SetUnit,c,nil) end
        c._ogmBoundUnit=nil
        c._ogmBoundGUID=nil
        c._ogmAnchorState=nil
        -- Do not synchronously rebuild the now-unbound container. That first
        -- UpdateAllAuras() was pure duplicate work during nameplate recycling.
        if c.SetUnit then pcall(c.SetUnit,c,unit) end
        c._ogmBoundUnit=unit
        c._ogmBoundGUID=nil
        -- Initial/recycled plate bind only: populate this container immediately.
        -- Do not do this on normal UNIT_AURA updates (that caused duplicate icons),
        -- but waiting only for Blizzard's next aura event can leave a freshly
        -- recycled nameplate blank for a noticeable moment.
        -- Native SetUnit handles initial population; no redundant timer/queue.
    end
    npStepEnd('native_bind',_npNative)
    local _npAnchor=npStepStart()
    local anchor=ownedAnchor(plate)
    if anchor and not isForbiddenObject(anchor) then
        -- Cache the complete anchor state: crowded camera turns can revisit a
        -- bound plate without any actual position/scale setting changing.
        local desiredScale = getQuickContainerScale()
        local desiredX = tonumber(db.offsetX) or 0
        local desiredY = (tonumber(db.offsetY) or 0)+6
        local state = c._ogmAnchorState
        local unchanged = state and state.anchor == anchor and state.friendly == isFriendly
            and state.scale == desiredScale and (isFriendly or
            (state.x == desiredX and state.y == desiredY))
        if not unchanged then
        pcall(c.ClearAllPoints,c)
        if isFriendly then
            -- Mirror the proven RIGHT-side CC anchor on the LEFT edge: same 5 px gap,
            -- same vertical center, with additional helpful auras growing LEFT.
            pcall(c.SetPoint,c,'RIGHT',anchor,'LEFT',-5,0)
            if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPRIGHT') end
            local FD=AnchorUtil and AnchorUtil.FlowDirection
            if c.SetFlowLayoutGrowthDirection and FD and FD.Left and FD.Down then
                pcall(c.SetFlowLayoutGrowthDirection,c,FD.Left,FD.Down)
            end
        else
            pcall(c.SetPoint,c,'BOTTOM',anchor,'TOP',tonumber(db.offsetX) or 0,(tonumber(db.offsetY) or 0)+6)
            if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPLEFT') end
            local FD=AnchorUtil and AnchorUtil.FlowDirection
            if c.SetFlowLayoutGrowthDirection and FD and FD.Right and FD.Down then
                pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,FD.Down)
            end
        end
        pcall(c.SetScale,c,desiredScale)
        -- Reuse the state record on plate recycling rather than allocating a
        -- fresh table for every bind during rapid camera turns.
        state = state or {}
        state.anchor, state.friendly, state.scale = anchor, isFriendly, desiredScale
        state.x, state.y = desiredX, desiredY
        c._ogmAnchorState = state
        end
    end
    -- Activation belongs to the binding lifecycle, not every aura refresh.
    -- Do not suppress native UNIT_AURA: Blizzard continues updating icons.
    npStepEnd('anchor',_npAnchor)
    local _npActivate=npStepStart()
    if not c._ogmPrimaryActivated then
        local okEnabled = not c.SetEnabled or pcall(c.SetEnabled,c,true)
        local okShown = okEnabled and pcall(c.Show,c)
        if okEnabled and okShown then c._ogmPrimaryActivated=true end
    end
    -- PERF: No recursive countdown traversal on initial nameplate binding.
    -- Individual aura-button hooks own their text styling; explicit theme
    -- updates may still traverse when the user changes appearance settings.
    npStepEnd('activate',_npActivate)
    -- Side-lane styling is already handled by bindLane() in updateSideLanes().
    -- Avoid repeating it for both lanes on every primary-row update.
    -- No manual UpdateAllAuras here. Once bound, CustomAuraContainerTemplate
    -- receives the live UNIT_AURA lifecycle itself. Forcing another full pass
    -- here was able to overlap its generated-button recycle on Forever.
    ownedDebuffRows[unit]=c
end

-- Diagnostic wrapper: disabled path is a direct call (no profiling allocations).
local _ogm_diag_original_updateOwnedDebuffRow = updateOwnedDebuffRow
updateOwnedDebuffRow = function(...)
    if not OGM_NP_DIAG.enabled then return _ogm_diag_original_updateOwnedDebuffRow(...) end
    return OGM_NP_Measure('Forever.owned_row',_ogm_diag_original_updateOwnedDebuffRow,...)
end
local function scrubSecureRow(c)
    if not c then return end
    c._ogmPrimaryActivated=nil
    cancelInitialAuraPopulate(c)
    if c.SetEnabled then pcall(c.SetEnabled,c,false) end
    -- Break the AuraContainer's unit binding before returning it to the pool.
    -- Hiding alone is not enough on Forever: generated AuraButtons can retain
    -- their last visual until the container receives another aura update.
    if c.SetUnit then pcall(c.SetUnit,c,nil) end
    c._ogmBoundUnit=nil
    c._ogmBoundGUID=nil
    -- IMPORTANT: never manually Hide() generated AuraButtons here. Blizzard's
    -- CustomAuraContainerTemplate owns and recycles those children. v20-v27's
    -- child scrub could leave a recycled button hidden until a later internal
    -- layout/aura pass, producing the observed disappear/reappear delay.
    -- SetUnit(nil) is the authoritative teardown; the next bind gets one bounded
    -- UpdateAllAuras above so the new plate is populated immediately.
    pcall(c.Hide,c)
    pcall(c.ClearAllPoints,c)
end

local function releaseOwnedDebuffRow(unit)
    local c=secureByUnit[unit]
    if c and c._ogmPlate then releaseSideLanes(c._ogmPlate) end
    -- Friendly plates intentionally have no primary secure row. Release their
    -- independent side lanes by the current plate, not by the absent row.
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate then releaseSideLanes(plate) end
    end
    if not c then
        for plate, bundle in pairs(sideLaneByPlate) do
            if bundle and ((bundle.cc and bundle.cc._ogmBoundUnit == unit)
                or (bundle.help and bundle.help._ogmBoundUnit == unit)) then
                releaseSideLanes(plate)
            end
        end
        return
    end
    -- v26: clear the unit binding, but KEEP this container reserved for its
    -- physical nameplate frame. It is never handed to another plate. This is the
    -- crucial difference from v23-v25 and matches Threat Plates' proven pool model.
    scrubSecureRow(c)
    c._ogmUnit=nil
    secureByUnit[unit]=nil
    ownedDebuffRows[unit]=nil
end

reanchorOwnedDebuffRows = function()
    -- Position changes must move the already-owned container; never acquire a
    -- replacement row just because the user nudged/dragged the anchor.
    for unit,c in pairs(secureByUnit) do
        if c and c._ogmUnit == unit then
            local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
            local a = plate and ownedAnchor(plate)
            if a and not isForbiddenObject(a) then
                pcall(c.ClearAllPoints,c)
                if UnitIsFriend('player',unit) then
                    pcall(c.SetPoint,c,'RIGHT',a,'LEFT',-3,0)
                    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPRIGHT') end
                    local FD=AnchorUtil and AnchorUtil.FlowDirection
                    if c.SetFlowLayoutGrowthDirection and FD and FD.Left and FD.Down then
                        pcall(c.SetFlowLayoutGrowthDirection,c,FD.Left,FD.Down)
                    end
                else
                    pcall(c.SetPoint,c,'BOTTOM',a,'TOP',tonumber(db.offsetX) or 0,(tonumber(db.offsetY) or 0)+6)
                    if c.SetFlowLayoutAnchorPoint then pcall(c.SetFlowLayoutAnchorPoint,c,'TOPLEFT') end
                    local FD=AnchorUtil and AnchorUtil.FlowDirection
                    if c.SetFlowLayoutGrowthDirection and FD and FD.Right and FD.Down then
                        pcall(c.SetFlowLayoutGrowthDirection,c,FD.Right,FD.Down)
                    end
                end
                pcall(c.SetScale,c,getQuickContainerScale())
            end
        end
    end
end

refreshOwnedDebuffRows = function()
    if db.enabled == false then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local ok,plates=pcall(C_NamePlate.GetNamePlates); if not ok or type(plates)~='table' then return end
    local active={}
    for _,plate in ipairs(plates) do
        local unit=plate.namePlateUnitToken or plate.unitToken
        if readable(unit) then active[unit]=true; updateOwnedDebuffRow(unit,plate) end
    end
    -- NAME_PLATE_UNIT_REMOVED can be missed/delayed during rapid recycling.
    -- Reconcile the pool against Blizzard's current plate list every bounded
    -- lifecycle refresh so no old unit can leave a floating icon behind.
    local stale={}
    for unit in pairs(secureByUnit) do if readable(unit) and not active[unit] then stale[#stale+1]=unit end end
    for _,unit in ipairs(stale) do releaseOwnedDebuffRow(unit) end
end

-- 1.3.9 CAMERA BURST GOVERNOR
-- NAME_PLATE_UNIT_ADDED can arrive in a large burst while the camera turns.
-- Binding CustomAuraContainerTemplate is legitimate but expensive because Blizzard
-- populates/recycles its secure aura groups. Never bind an entire camera burst in
-- one frame. Queue each unit once and drain one plate per frame. Removed/recycled
-- units are discarded before any aura work. This is bounded/event-driven: no OnUpdate.
local _ogmPlateBindQueue, _ogmPlateBindQueued, _ogmPlateBindGUID = {}, {}, {}
local _ogmPlateBindHead = 1
local _ogmPlateBindDrainPending = false
local function drainQueuedNameplateBind()
    _ogmPlateBindDrainPending = false
    local unit
    while _ogmPlateBindHead <= #_ogmPlateBindQueue do
        local candidate = _ogmPlateBindQueue[_ogmPlateBindHead]
        _ogmPlateBindQueue[_ogmPlateBindHead] = false
        _ogmPlateBindHead = _ogmPlateBindHead + 1
        if _ogmPlateBindQueued[candidate] then unit = candidate; break end
    end
    if unit then
        _ogmPlateBindQueued[unit] = nil
        local queuedGUID = _ogmPlateBindGUID[unit]
        _ogmPlateBindGUID[unit] = nil
        if db.enabled ~= false and (db.targetOnly ~= true or (UnitExists('target') and UnitIsUnit(unit, 'target'))) and UnitExists(unit) and (not queuedGUID or (not (issecretvalue and issecretvalue(queuedGUID)) and (function() local currentGUID = UnitGUID(unit); return not (issecretvalue and issecretvalue(currentGUID)) and currentGUID == queuedGUID end)()) or (issecretvalue and issecretvalue(queuedGUID))) and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
            if ok and plate and not isForbiddenObject(plate) then
                pcall(updateOwnedDebuffRow, unit, plate)
            end
        end
    end
    -- Canceled units can leave tombstones behind the queue head.  Compact
    -- them now rather than scheduling more timer callbacks for dead plates.
    while _ogmPlateBindHead <= #_ogmPlateBindQueue do
        local nextUnit = _ogmPlateBindQueue[_ogmPlateBindHead]
        if nextUnit and _ogmPlateBindQueued[nextUnit] then break end
        _ogmPlateBindQueue[_ogmPlateBindHead] = false
        _ogmPlateBindHead = _ogmPlateBindHead + 1
    end
    if _ogmPlateBindHead <= #_ogmPlateBindQueue and C_Timer and C_Timer.After then
        _ogmPlateBindDrainPending = true
        -- All-player debuffs require a wider native aura scan per newly visible
        -- plate. Keep every aura and the one-bind-per-callback governor, but
        -- spread crowded camera bursts further apart to protect frame time.
        C_Timer.After(db.showAllDebuffs ~= false and 0.035 or 0.01, drainQueuedNameplateBind)
    else
        _ogmPlateBindQueue = {}
        _ogmPlateBindHead = 1
    end
end
-- Diagnostic wrapper: disabled path is a direct call (no profiling allocations).
local _ogm_diag_original_drainQueuedNameplateBind = drainQueuedNameplateBind
drainQueuedNameplateBind = function(...)
    if not OGM_NP_DIAG.enabled then return _ogm_diag_original_drainQueuedNameplateBind(...) end
    return OGM_NP_Measure('Forever.drain_bind',_ogm_diag_original_drainQueuedNameplateBind,...)
end
local function queueNameplateBind(unit)
    -- Compatibility owns the entire nameplate scope: avoid even queuing or
    -- resolving GUIDs for hundreds of camera-visible plates we cannot render.
    if db.enabled == false or not unit or (secureByUnit[unit] and secureByUnit[unit]._ogmBoundUnit == unit) or _ogmPlateBindQueued[unit]
        or (Addon.CompatibilityOwnsScope and Addon:CompatibilityOwnsScope('nameplates'))
        or (Addon.MidnightNameplates and Addon.MidnightNameplates._compatSuspended) then return end
    -- Target-only must never queue/bind the other 99 nameplates in a camera burst.
    -- Target changes are handled by PLAYER_TARGET_CHANGED; this gate only
    -- prevents unnecessary Blizzard AuraContainer initialization.
    if db.targetOnly == true and (not UnitExists('target') or not UnitIsUnit(unit, 'target')) then return end
    _ogmPlateBindQueued[unit] = true
    _ogmPlateBindGUID[unit] = UnitGUID(unit)
    _ogmPlateBindQueue[#_ogmPlateBindQueue+1] = unit
    if not _ogmPlateBindDrainPending and C_Timer and C_Timer.After then
        _ogmPlateBindDrainPending = true
        C_Timer.After(0, drainQueuedNameplateBind)
    end
end
-- Diagnostic wrapper: disabled path is a direct call (no profiling allocations).
local _ogm_diag_original_queueNameplateBind = queueNameplateBind
queueNameplateBind = function(...)
    if not OGM_NP_DIAG.enabled then return _ogm_diag_original_queueNameplateBind(...) end
    return OGM_NP_Measure('Forever.queue_bind',_ogm_diag_original_queueNameplateBind,...)
end
local function cancelQueuedNameplateBind(unit)
    if not unit then return end
    _ogmPlateBindQueued[unit] = nil
    _ogmPlateBindGUID[unit] = nil
    -- PERF: Cancellation must be O(1) during camera-turn removal bursts.
    -- The drain already treats entries absent from _ogmPlateBindQueued as
    -- tombstones and skips them without touching Blizzard aura containers.
    -- Scanning the entire pending queue for every removed plate was O(N^2).
    -- Leave queue storage intact until the bounded drain compacts it.
end

-- Release ALL GODMODE-owned bindings on OFF, including friendly-only lanes.
-- Containers remain allocated for safe reuse; no SavedVariables are modified.
stopOwnedNameplateAuras = function()
    for i = #_ogmPlateBindQueue, 1, -1 do _ogmPlateBindQueue[i] = nil end
    _ogmPlateBindHead = 1
    for unit in pairs(_ogmPlateBindQueued) do _ogmPlateBindQueued[unit] = nil; _ogmPlateBindGUID[unit] = nil end
    for plate in pairs(sideLaneByPlate) do releaseSideLanes(plate) end
    for _, bundle in ipairs(sideLanePool) do
        if bundle then
            disableLane(bundle.cc)
            disableLane(bundle.help)
            bundle._plate = nil
        end
    end
    for unit in pairs(secureByUnit) do releaseOwnedDebuffRow(unit) end
    for _, c in ipairs(securePool) do
        if c then
            cancelInitialAuraPopulate(c)
            if c._ogmBoundUnit or c._ogmUnit then scrubSecureRow(c) end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        -- Target-only mode must immediately hide the previous target row and
        -- show the new target row. Reuse the proven v31/v34 full plate refresh;
        -- do not alter Blizzard AuraContainer lifecycle/update behavior.
        if db.targetOnly == true then refreshOwnedDebuffRows() end
        return
    elseif event == "CVAR_UPDATE" then
        local cvarName = tostring(unit or "")
        if cvarName:lower() == "nameplateaurascale" then
            -- 70170 can rewrite this CVar while loading. Never import that reset
            -- into GODMODE's SavedVariables. Keep the user's saved 1-10 size.
            local wanted = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
            local current = tonumber(getNativeCVar('nameplateAuraScale'))
            if current and math.abs(current - wanted) > 0.001 and not inCombatLockdown() then
                setNativeCVar('nameplateAuraScale', wanted)
            end
        elseif cvarName:lower() == tostring(friendlyPlayerAuraCVarName()):lower() and not inCombatLockdown() then
            syncNativeFriendlyPlayerAuraOwnership()
        end
        return
    elseif event == "UNIT_AURA" then
        -- PERFORMANCE FIX: CustomAuraContainerTemplate already receives and processes
        -- UNIT_AURA for an existing binding. Re-running GODMODE's full ownership,
        -- Smart Filter database construction, side-lane binding, styling and external
        -- aura-tree suppression here multiplied work by every visible nameplate aura.
        -- Only use UNIT_AURA as the fallback first-bind path if this unit somehow did
        -- not receive/finish NAME_PLATE_UNIT_ADDED. Existing rows require ZERO addon work.
        -- UNIT_AURA also fires for units that are not nameplates. Friendly
        -- nameplates intentionally use side lanes and never enter secureByUnit;
        -- queuing them on every aura change creates repeated no-op bind work.
        -- Their initial bind is owned by NAME_PLATE_UNIT_ADDED.
        if type(unit) == 'string' and unit:match('^nameplate%d+$')
            and not UnitIsFriend('player', unit) and not secureByUnit[unit] then
            -- A first-bind fallback must use the same burst governor as
            -- NAME_PLATE_UNIT_ADDED. Never synchronously construct/rebind a
            -- Blizzard AuraContainer inside a UNIT_AURA event storm.
            queueNameplateBind(unit)
        end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        cancelQueuedNameplateBind(unit)
        if unit then releaseOwnedDebuffRow(unit) end
        return
    end
    if event == "ADDON_LOADED" then
        if false and unit == "GODMODENameplates_Forever" then
            -- Forever only: the nameplate addon can finish/rebuild its aura rows
            -- after our own ADDON_LOADED pass. Re-apply the GODMODE 10/10 startup
            -- baseline after those rows exist, otherwise its late layout wins and
            -- the player sees an old/smaller size until pressing Size + manually.
            local function lateTenOfTen()
                if not persistenceReady then return end
                -- Re-apply the user's saved state after late nameplate rebuilds.
                -- Never force 10/10 here: that was the persistence regression.
                sessionQuickSizeLevel = clamp(math.floor(tonumber(db.quickSizeLevel) or 6), 1, 10)
                db.auraScale = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
                attachGODMODENameplatesCompat()
                applyLiveQuickControls()
                refreshAll()
            end
            C_Timer.After(0, lateTenOfTen)
            C_Timer.After(0.50, lateTenOfTen)
            C_Timer.After(1.50, lateTenOfTen)
            C_Timer.After(3.00, lateTenOfTen)
            return
        end
        if unit ~= AddonName then return end
        loadPersistentState()
        -- 70170: GODMODE SavedVariables are the source of truth. The beta can
        -- reset Blizzard's nameplateAuraScale CVar during an update; importing it
        -- here changed existing users' 1-10 size unexpectedly. Mirror our saved
        -- value OUT to Blizzard instead, never the other way around.
        sessionQuickSizeLevel = clamp(math.floor(tonumber(db.quickSizeLevel) or 6), 1, 10)
        db.auraScale = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
        setNativeCVar('nameplateAuraScale', db.auraScale)
        updateAnchor()
        quick:ClearAllPoints()
        quick:SetPoint(db.quickPoint or "CENTER", UIParent, db.quickPoint or "CENTER", tonumber(db.quickX) or 0, tonumber(db.quickY) or 0)
        updateStatus()
        -- 1.3.2 persistence fix: the saved source filter must be applied to the
        -- preallocated Blizzard AuraContainers on every login/reload. Previously
        -- the checkbox state loaded correctly, but the containers kept their
        -- creation-time ALL-player filter until the user toggled the option.
        if applyDebuffSourceMode then applyDebuffSourceMode() end
        C_Timer.After(0, function()
            if applyDebuffSourceMode then applyDebuffSourceMode() end
            refreshAll()
        end)
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        syncNativeNpcAuraOwnership()
        syncNativeFriendlyPlayerAuraOwnership()
        if pendingCombatRefresh then
            C_Timer.After(0, function()
                if not inCombatLockdown() then
                    refreshAll()
                    if db.anchorShown then updateAnchor() end
                end
            end)
        end
        return
    elseif event == "PLAYER_LOGOUT" then
        persist()
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        -- Camera turns can add many plates in the same frame. The secure aura
        -- container bind is the expensive operation, so spread those binds instead
        -- of executing the whole burst synchronously inside this event.
        queueNameplateBind(unit)
    else
        C_Timer.After(0, refreshAll)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            -- Some UI/nameplate layouts finish one frame later on /reload.
            -- One final bounded pass guarantees that the exact SavedVariables
            -- font/font-size/outline wins after every reload.
            C_Timer.After(0.50, function()
                syncNativeNpcAuraOwnership()
                refreshOwnedDebuffRows()
            end)
        end
    end
end)

-- Do NOT poll/re-style nameplate aura rows on OnUpdate.
-- Forever/Blizzard refreshes protected aura containers while countdowns are
-- ticking. Re-applying GODMODE positioning/theme every second causes the timer
-- text to visibly jump between Blizzard and GODMODE placement.
-- We now refresh only from real lifecycle/config events (plate added, login,
-- combat end, user setting changes, container show/rebuild).

SLASH_OGMNP1 = "/ogmnp"
SlashCmdList.OGMNP = function(message)
    local command, value = tostring(message or ""):match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "unlock" or command == "move" then
        setAnchorShown(true, true)
    elseif command == "lock" then
        setAnchorShown(false, true)
    elseif command == "panel" or command == "menu" then
        showQuickPanel()
    elseif command == "scale" then
        local scale=clamp(value,.60,2.00); setSessionQuickSizeLevel(nearestQuickSizeLevel(scale)); setNativeCVar('nameplateAuraScale',db.auraScale); persist(); applyLiveQuickControls(); refreshAll(); updateStatus()
    elseif command == "x" then
        db.offsetX = clamp(value, -1000, 1000); persist(); updateAnchor(); refreshAll(); updateStatus()
    elseif command == "y" then
        db.offsetY = clamp(value, -500, 1000); persist(); updateAnchor(); refreshAll(); updateStatus()
    elseif command == "on" then
        db.enabled = true; persist(); updateManagedVisibility(); refreshAll()
    elseif command == "off" then
        db.enabled = false; persist(); updateManagedVisibility(); refreshAll()
    elseif command == "reset" then
        db.enabled, db.auraScale, db.offsetX, db.offsetY = true, defaults.auraScale, defaults.offsetX, defaults.offsetY
        persist(); updateAnchor(); refreshAll(); updateStatus()
    elseif command == "status" then
        print(string.format("|cffffd200OmniCC GODMODE:|r scale %.2f, X %d, Y %d", db.auraScale or 0, db.offsetX or 0, db.offsetY or 0))
    else
        showQuickPanel()
        print("|cffffd200OmniCC GODMODE:|r /ogmnp unlock, lock, panel, scale, x, y, reset")
    end
end


local function hideMoveAnchorForSession()
    db.anchorShown = false
    if anchor then
        anchor:Hide()
    end
end


applyLiveQuickControls = function()
    persist(false)

    for container in pairs(managedContainers) do
        if container and not isForbiddenObject(container) then
            -- Aura Filters are NPC NAMEPLATE filters. Apply them directly to the
            -- live renderer we already own; do not create a second aura system.
            applySmartAuraStyle(container)
            local info = ownedPMH[container]

            if info and info.plate then
                local anchorFrame = getPMHAnchor(info.plate)
                if anchorFrame and not isForbiddenObject(anchorFrame) then
                    -- Whole-row scale only. PMH remains the sole owner of icon
                    -- size, border geometry, cooldown layout and spacing.
                    if container.SetScale then
                        local liveScale = getQuickContainerScale()
                        if info.kind and Addon.ForeverAuraText and Addon.ForeverAuraText.GetExternalIconScale then
                            liveScale = liveScale * Addon.ForeverAuraText:GetExternalIconScale(info.kind)
                        end
                        pcall(container.SetScale, container, liveScale)
                    end
                    if info.kind and Addon.ForeverAuraText and Addon.ForeverAuraText.StyleExternalContainer then
                        Addon.ForeverAuraText:StyleExternalContainer(container, info.kind)
                    end
                    applyNameplateCountdownTextStyle(container)
                    -- No re-anchor/proxy ownership here.  Repeated SetPoint fights
                    -- with GODMODE Nameplates were the source of recursion and lag.
                end
            end
        end
    end

    -- v20: move/scale the single existing GODMODE rows in place. This avoids
    -- acquiring a second AuraContainer and leaving the previous buttons behind.
    if reanchorOwnedDebuffRows then pcall(reanchorOwnedDebuffRows) end

    if db.anchorShown then
        pcall(updateAnchor)
    end
end
Addon.ForeverNameplates = {
    GetSettings = function()
        db.quickSizeLevel = sessionQuickSizeLevel
        db.auraScale = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or 3.00
        return db
    end,
    Refresh = refreshAll,
    Save = persist,
    ForceSave = function() persist() end,
    SetEnabled = function(enabled)
        db.enabled = not not enabled
        persist()
        refreshAll()
        updateManagedVisibility()
    end,
    SetScale = function(value)
        local scale=clamp(value,0.60,2.00)
        setSessionQuickSizeLevel(nearestQuickSizeLevel(scale))
        setNativeCVar('nameplateAuraScale',db.auraScale)
        persist()
        refreshAll()
        updateStatus()
    end,
    SetOffset = function(x, y)
        if x ~= nil then db.offsetX = clamp(tonumber(x) or db.offsetX, -300, 300) end
        if y ~= nil then db.offsetY = clamp(tonumber(y) or db.offsetY, -150, 300) end
        persist()
        applyLiveQuickControls()
        updateStatus()
    end,
    ToggleAnchor = function() setAnchorShown(not db.anchorShown, true) end,
    ShowQuickPanel = showQuickPanel,
    ShowCombatFullPanel = showCombatFullPanel,
    GetOption = function(key) return db[key] end,
    NudgeCCRightSize = function(delta)
        if db.ccPlacement ~= 'RIGHT' then return end
        local old = math.max(16,math.min(64,tonumber(db.ccRightSize) or 30))
        local nextSize = math.max(16,math.min(64,old+(tonumber(delta) or 0)))
        if nextSize == old then return end
        db.ccRightSize = nextSize
        persist()
        -- Only touch existing CC lane scales; never rebuild aura groups or
        -- run a full nameplate refresh for a cosmetic adjustment.
        for _,bundle in ipairs(sideLanePool) do
            local c = bundle.cc
            if c and c._ogmLaneActivated and c._ogmLaneSide == 'RIGHT' then
                local scale = getQuickContainerScale() * nextSize / 30
                if c._ogmAppliedLaneScale ~= scale then
                    local ok = pcall(c.SetScale,c,scale)
                    if ok then c._ogmAppliedLaneScale = scale end
                end
            end
        end
    end,
    SetOption = function(key, value)
        if defaults[key] == nil then return end
        if key == 'ccPlacement' then
            value = (value == 'TOP') and 'TOP' or 'RIGHT'
        elseif key == 'enabled' then
            value = value ~= false
        end
        db[key] = value
        invalidateCandidateConfiguration()
        persist()
        if key == 'showAllDebuffs' and applyDebuffSourceMode then applyDebuffSourceMode() end
        applyLiveQuickControls()
        if key == 'enabled' and updateManagedVisibility then updateManagedVisibility() end
        -- Filter/source changes must immediately re-evaluate every visible NPC
        -- nameplate aura. Previously the menu saved correctly but the live NPC
        -- renderer kept showing its old children until another unrelated refresh.
        local isFilterKey = key == 'filterPreset' or key == 'showAllDebuffs' or key == 'targetOnly'
            or key == 'showStuns' or key == 'showFears' or key == 'showRoots' or key == 'showSlows'
            or key == 'showSilences' or key == 'showIncapacitates' or key == 'showDisarms' or key == 'showTaunts'
            or key == 'showInterrupts' or key == 'showImmunities' or key == 'showDefensives'
            or key == 'showDamageReduction' or key == 'showAbsorptionShields' or key == 'showOffensives'
            or key == 'showHealingReduction' or key == 'showDots' or key == 'showBleeds' or key == 'showPoisons'
            or key == 'showDiseases' or key == 'showCurses' or key == 'showMagic' or key == 'showBossMechanics'
            or key == 'showRaidMechanics' or key == 'customSourceMine' or key == 'customSourceGroup' or key == 'customSourceOthers'
        if isFilterKey then
            for _, row in ipairs(securePool or {}) do
                if row then
                    applyExactCustomCandidates(row)
                    if row._ogmUnit and row.UpdateAllAuras then pcall(row.UpdateAllAuras,row) end
                end
            end
            for _, bundle in ipairs(sideLanePool or {}) do
                if bundle and bundle.cc then
                    applyExactCustomLaneCandidates(bundle.cc)
                    if bundle.cc._ogmBoundUnit and bundle.cc.UpdateAllAuras then pcall(bundle.cc.UpdateAllAuras,bundle.cc) end
                end
            end
        end
        if (key == 'enabled' or key == 'ccPlacement' or isFilterKey) and refreshAll then refreshAll() end
    end,
}

local lastForeverNameplateTextSignature
function Addon.ForeverNameplates:RefreshThemeAppearance()
    -- Color-picker drag is appearance-only. Avoid rebuilding countdown text
    -- formatters on every swipe-color mouse movement.
    local profile = Addon.db and Addon.db.profile
    local theme = profile and profile.themes and profile.themes.nameplates
    if not theme then return end
    local parts = {
        tostring(theme.themeText), tostring(theme.drawText),
        tostring(theme.font), tostring(theme.fontSize), tostring(theme.fontFlags),
        tostring(theme.point), tostring(theme.offsetX), tostring(theme.offsetY),
        tostring(theme.defaultTextColor), tostring(theme.roundingMode),
        tostring(theme.minDuration), tostring(theme.tenthsThreshold),
        tostring(theme.minutesThreshold), tostring(theme.abbrevThreshold),
        tostring(theme.hoursThreshold), tostring(theme.daysThreshold),
        tostring(theme.weeksThreshold), tostring(theme.scaleText),
        tostring(theme.minScale), tostring(theme.showZero),
    }
    for _, entry in ipairs(theme.textColors or {}) do
        parts[#parts + 1] = tostring(entry.threshold)
        parts[#parts + 1] = tostring(entry.color)
    end
    local signature = table.concat(parts, '|')
    if signature ~= lastForeverNameplateTextSignature then
        lastForeverNameplateTextSignature = signature
        for cd in pairs(ownedCountdowns) do
            cd._ogmActionColorFormatter = nil
            cd._ogmActionColorSource = nil
            applyNameplateCountdownFormatter(cd)
        end
    else
        -- The appearance renderer has its own per-cooldown signature and skips
        -- unchanged values. No aura container lifecycle or global refresh.
        refreshNameplateThemeAppearance()
    end
end

_G.OmniCC_GODMODE = _G.OmniCC_GODMODE or Addon

function Addon.ForeverNameplates:SetShowAllDebuffs(enabled)
    db.showAllDebuffs = enabled ~= false
    persist()
    applyDebuffSourceMode()
    updateStatus()
end

function Addon.ForeverNameplates:GetShowAllDebuffs()
    return db.showAllDebuffs ~= false
end

function Addon.ForeverNameplates:SetTargetOnly(enabled)
    db.targetOnly = enabled == true
    persist()
    refreshOwnedDebuffRows()
    updateStatus()
end

function Addon.ForeverNameplates:GetTargetOnly()
    return db.targetOnly == true
end

function Addon.ForeverNameplates:SetFriendlyAuraOption(kind, enabled)
    local key = kind == 'HOTS' and 'friendlyHots' or (kind == 'BUFFS' and 'friendlyBuffs' or (kind == 'DEBUFFS' and 'friendlyDebuffs' or nil))
    if not key then return end
    db[key] = enabled ~= false
    persist()

    -- Hot-switch only the requested friendly lane.  Do not rebuild/rebind the
    -- shared AuraContainer: that briefly clears the unrelated live groups.
    for plate,b in pairs(sideLaneByPlate) do
        local c = b and b.help
        if c and c.SetAuraGroupMaxFrameCount then
            local hotsOn = db.friendlyHots ~= false
            local buffsOn = db.friendlyBuffs ~= false
            local helpfulOn = hotsOn or buffsOn
            local debuffsOn = db.friendlyDebuffs ~= false
            local candidates={}
            if hotsOn and not buffsOn then
                candidates={includeSpellIDs=FRIENDLY_HOT_SPELLS}
            elseif buffsOn and not hotsOn then
                candidates={excludeSpellIDs=FRIENDLY_HOT_SPELLS}
            end
            if c.SetAuraGroupCandidateFilters then
                pcall(c.SetAuraGroupCandidateFilters,c,'ogm_lane_HELPFUL',candidates)
            end
            pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_lane_HELPFUL',helpfulOn and 6 or 0)
            pcall(c.SetAuraGroupMaxFrameCount,c,'ogm_lane_DEBUFFS',debuffsOn and 6 or 0)
            local anyOn = helpfulOn or debuffsOn
            if anyOn then
                local unit = c._ogmBoundUnit
                local anchor = plate and ownedAnchor(plate)
                if unit and anchor then
                    bindLane(c,unit,anchor,'LEFT')
                    -- Toggle action only (not UNIT_AURA hot path): rebuild this one
                    -- owned container now so disabled groups cannot leave stale icons.
                    if c.UpdateAllAuras then pcall(c.UpdateAllAuras,c) end
                end
            else
                disableLane(c)
            end
        end
    end
end

function Addon.ForeverNameplates:GetFriendlyAuraOption(kind)
    local key = kind == 'HOTS' and 'friendlyHots' or (kind == 'BUFFS' and 'friendlyBuffs' or (kind == 'DEBUFFS' and 'friendlyDebuffs' or nil))
    return key and db[key] ~= false or false
end

function Addon.ForeverNameplates:GetCountdownTextSize()
    return getSavedCountdownTextSize()
end

local function refreshOwnedCountdownFontStrings()
    -- CD Text +/- is intentionally O(number of visible GODMODE cooldowns).
    -- Do not recursively scan every AuraContainer: on 70170 that causes a visible hitch.
    for cd in pairs(ownedCountdowns) do
        styleCountdownFontString(cd, true)
    end
end

function Addon.ForeverNameplates:SetCountdownTextSize(value)
    local requested = clamp(math.floor((tonumber(value) or getSavedCountdownTextSize()) + 0.5), 6, 48)
    db.countdownTextSize = requested
    -- Dedicated NPC aura countdown size only. Do not mutate the Nameplates
    -- theme/font settings: existing users keep their exact old visual style.
    persist()
    -- Single synchronous, owned-font-only pass. No deferred retries, aura
    -- rebuilds, formatter allocation, or global nameplate scans per click.
    refreshOwnedCountdownFontStrings()
end
function Addon.ForeverNameplates:NudgeCountdownTextSize(delta)
    self:SetCountdownTextSize(self:GetCountdownTextSize() + (tonumber(delta) or 0))
end

function Addon.ForeverNameplates:NudgePosition(dx, dy)
    db.offsetX = clamp((tonumber(db.offsetX) or 0) + (tonumber(dx) or 0), -300, 300)
    db.offsetY = clamp((tonumber(db.offsetY) or 0) + (tonumber(dy) or 0), -150, 300)
    persist()
    applyLiveQuickControls()
end


function Addon.ForeverNameplates:NudgeSize(direction)
    direction = tonumber(direction) or 0
    if direction == 0 then return end

    -- Re-read the effective saved scale every click instead of trusting a stale
    -- quickSizeLevel, so +/- always moves exactly one 1-10 step.
    local currentLevel = clamp(math.floor(tonumber(sessionQuickSizeLevel) or 6), 1, 10)
    local step = direction > 0 and 1 or -1
    local nextLevel = clamp(currentLevel + step, 1, 10)
    setSessionQuickSizeLevel(nextLevel)
    -- Mirror the exact GODMODE 1-10 scale into Blizzard's persistent account CVar.
    -- 6/10 = 1.10, 10/10 = 1.50.
    setNativeCVar('nameplateAuraScale', QUICK_SCALE_BY_LEVEL[nextLevel] or QUICK_SCALE_BY_LEVEL[6])

    persist()
    applyLiveQuickControls()
    refreshAll()

    print("|cffffd200OmniCC GODMODE:|r NPC aura size " ..
        tostring(nextLevel) .. "/10")
end


function Addon.ForeverNameplates:ResetQuickControls()
    db.offsetX = defaults.offsetX or 0
    db.offsetY = defaults.offsetY or 0
    setSessionQuickSizeLevel(6)
    setNativeCVar('nameplateAuraScale', QUICK_SCALE_BY_LEVEL[6])
    persist()
    applyLiveQuickControls()
end

_G.OmniCC_GODMODE_Nameplates = Addon.ForeverNameplates

_G.OmniCC_GODMODE.ForeverNameplates = Addon.ForeverNameplates




-- GODMODE Forever quick-control adapter.
-- Kept separate from the Forever aura engine so it cannot break engine initialization.
Addon.ForeverNameplates = Addon.ForeverNameplates or {}
_G.OmniCC_GODMODE_Nameplates = Addon.ForeverNameplates

local function OGM_GetForeverNPDB()
    OmniCC_GODMODE_ForeverNameplatesDB = OmniCC_GODMODE_ForeverNameplatesDB or {}
    return OmniCC_GODMODE_ForeverNameplatesDB
end

-- OGM_STARTUP_ANCHOR_HIDE_GUARD
local _ogmStartupAnchorGuard = CreateFrame('Frame')
local function OGM_ApplyForeverSavedNameplateState()
    -- Re-apply saved state after PLAYER_LOGIN / entering world. Fresh installs
    -- default to 6/10, while existing users keep their chosen value.
    if persistenceReady then
        sessionQuickSizeLevel = clamp(math.floor(tonumber(db.quickSizeLevel) or 6), 1, 10)
        db.auraScale = QUICK_SCALE_BY_LEVEL[sessionQuickSizeLevel] or QUICK_SCALE_BY_LEVEL[6]
        rawset(_G, SCALAR.quickSizeLevel, sessionQuickSizeLevel)
        rawset(_G, SCALAR.auraScale, db.auraScale)
    end
    -- The main ADDON_LOADED / PLAYER_ENTERING_WORLD lifecycle already applies
    -- source filters and visible-plate styling. Do not duplicate refreshAll(),
    -- managed-container restyling and filter rebuilds during /reload.
    db.anchorShown = false
    if anchor then anchor:Hide() end
end
_ogmStartupAnchorGuard:RegisterEvent('PLAYER_LOGIN')
_ogmStartupAnchorGuard:RegisterEvent('PLAYER_ENTERING_WORLD')
_ogmStartupAnchorGuard:SetScript('OnEvent', function()
    OGM_ApplyForeverSavedNameplateState()
end)


-- OGM_TARGET_ANCHOR_FOLLOWER
local _ogmTargetAnchorFollower = CreateFrame("Frame")
_ogmTargetAnchorFollower:RegisterEvent("PLAYER_TARGET_CHANGED")
_ogmTargetAnchorFollower:SetScript("OnEvent", function()
    if db.anchorShown then
        updateAnchor()
    end
end)

-- Never leave Blizzard's persistent native nameplate-aura CVar disabled after
-- a normal logout/reload. This makes uninstall-after-exit safe.
local __ogmCVarRestore=CreateFrame('Frame')
__ogmCVarRestore:RegisterEvent('PLAYER_LOGOUT')
__ogmCVarRestore:SetScript('OnEvent',function() restoreNativeNpcAuraCVar(); restoreNativeFriendlyPlayerAuraCVar() end)
