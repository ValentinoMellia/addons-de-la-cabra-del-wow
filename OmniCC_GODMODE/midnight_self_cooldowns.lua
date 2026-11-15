-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface == 16001 then return end
local _, Addon = ...

-- Portrait countdowns follow the Action Bars (default) theme while Auto-Fit is OFF.
-- Auto-Fit ON temporarily selects godmode_autofit without mutating saved themes.
local function ApplyPortraitCountdownTheme(cd)
 if not cd then return end
 local p=Addon and Addon.db and Addon.db.profile
 local auto=p and p.godmodeAutoFitEnabled == true
 local t=p and p.themes and p.themes.default
 if not t then return end
 -- Apply the complete selected text theme, not only a formatter. The native
 -- countdown keeps its own duration clock; no aura container is rebuilt.
 if Addon.CreateThemer then
  local ok,styler=pcall(Addon.CreateThemer,Addon,t)
  if ok and type(styler)=='function' then pcall(styler,cd) end
 end
 if Addon.CreateCountdownFormatter and cd.SetCountdownFormatter then
  local ok,fmt=pcall(Addon.CreateCountdownFormatter,Addon,t)
  if ok and fmt then
   pcall(cd.SetCountdownFormatter,cd,fmt)
   cd._ogmActionColorFormatter=fmt
   cd._ogmActionColorSource=t
  end
 end
 -- Portrait aura cooldowns belong to Action Bars, independently of Auto-Fit.
 -- Reapply the native swipe immediately: Blizzard can retain the old swipe tint
 -- when the text themer/formatter changes without an aura lifecycle update.
 if cd.SetSwipeColor and t.themeCooldown ~= false and t.themeSwipeColor and t.swipeColor and Addon.HexToRGBA then
  local ok,r,g,b,a=pcall(Addon.HexToRGBA,t.swipeColor)
  if ok and r then pcall(cd.SetSwipeColor,cd,r,g,b,a or 1) end
 end
 -- Portrait-only placement: keep native cooldown digits centered regardless of theme anchor.
 -- Apply after the theme styler so bottom/top theme settings cannot move them.
 if cd.GetCountdownFontString then
  local ok,fs=pcall(cd.GetCountdownFontString,cd)
  if ok and fs then
   pcall(function()
    fs:ClearAllPoints()
    fs:SetPoint('CENTER',cd,'CENTER',4,0)
    fs:SetJustifyH('CENTER')
    fs:SetJustifyV('MIDDLE')
   end)
  end
 end
 if auto and cd.GetCountdownFontString then
  local ok,fs=pcall(cd.GetCountdownFontString,cd)
  if ok and fs and fs.GetFont and fs.SetFont then
   local good,font,_,flags=pcall(fs.GetFont,fs)
   local width=cd.GetWidth and cd:GetWidth() or 0
   local height=cd.GetHeight and cd:GetHeight() or 0
   local slider=math.max(0,math.min(99,tonumber(t.fontSize) or 50))
   local preferred=5+10*slider/99
   local bound=math.max(1,math.min(width or 0,height or 0)*0.82)
   if good and font and width>0 and height>0 then
    pcall(fs.SetFont,fs,font,math.min(preferred,bound),flags)
    if Addon.FitAutoText then pcall(Addon.FitAutoText,Addon,fs,cd,t) end
   end
  end
 end
end


-- Midnight: active self-cooldown / self-buff strip for the Blizzard PlayerFrame.
-- Completely separate from Player CC.  It intentionally tracks abilities the
-- player ACTIVATES (Wings, Sprint, Evasion, major defensives/offensives, etc.)
-- and does not use the CC portrait system.
local Module = CreateFrame('Frame')
Addon.MidnightSelfCooldowns = Module
_G.OmniCC_GODMODE_SelfCooldowns = Module

local defaults = { enabled=true, showPersistentBuffs=true, showActivatedEffects=true, showHots=true, showFoodBuffs=true, customAllow='', customBlock='', maxIcons=10, iconSize=24, spacing=3, x=36, y=-38 }
local db, holder
local buttons = {}
local scanElapsed = 0

-- Public spell/aura IDs for player-activated timed class effects.  Midnight can
-- protect aura payload fields during combat, so we do NOT need to inspect or
-- compare protected aura names/IDs.  Instead we ask Blizzard directly whether
-- each known public aura ID is active with GetPlayerAuraBySpellID().
--
-- Multiple IDs are intentionally kept for spec/talent/legacy aura variants;
-- only IDs that Blizzard reports as active are displayed.  This makes one table
-- work across Midnight builds/specs without showing nonexistent abilities.
local SELF_EFFECTS = {
    DEATHKNIGHT = {
        48707,   -- Anti-Magic Shell
        48792,   -- Icebound Fortitude
        49028,   -- Dancing Rune Weapon
        51271,   -- Pillar of Frost
        55233,   -- Vampiric Blood
        194679,  -- Rune Tap
        207289,  -- Unholy Assault
        219809,  -- Tombstone
        47568,   -- Empower Rune Weapon
        49039,   -- Lichborne
        194918,  -- Blighted Rune Weapon / variant
        273947,  -- Hemostasis
        377101,  -- Bonegrinder / talent proc activated window
        391519,  -- Abomination Limb related self window
        42650,   -- Army of the Dead cast window (if exposed as aura)
    },
    DEMONHUNTER = {
        191427,  -- Metamorphosis
        187827,  -- Metamorphosis (Vengeance aura variant)
        198589,  -- Blur
        196555,  -- Netherwalk
        188501,  -- Spectral Sight
        212800,  -- Blur/defensive variant
        206803,  -- Rain from Above
        196718,  -- Darkness (self effect when exposed)
        258920,  -- Immolation Aura window
        391172,  -- Soulmonger / defensive window
        427912,  -- Fel Barrage activation window
    },
    DRUID = {
        1850,    -- Dash
        5215,    -- Prowl
        22812,   -- Barkskin
        29166,   -- Innervate
        61336,   -- Survival Instincts
        106898,  -- Stampeding Roar
        106951,  -- Berserk
        102543,  -- Incarnation: King of the Jungle
        102558,  -- Incarnation: Guardian of Ursoc
        102560,  -- Incarnation: Chosen of Elune
        33891,   -- Incarnation: Tree of Life
        194223,  -- Celestial Alignment
        252216,  -- Tiger Dash
        102342,  -- Ironbark (when self-cast)
        22842,   -- Frenzied Regeneration
        197721,  -- Flourish
        391528,  -- Convoke/hero activation window variant
        391891,  -- Adaptive Swarm/hero self window variant
        429438,  -- Incarnation/hero variant
    },
    EVOKER = {
        363916,  -- Obsidian Scales
        374348,  -- Renewing Blaze
        375087,  -- Dragonrage
        370960,  -- Emerald Communion
        374227,  -- Zephyr
        378464,  -- Time Spiral
        357170,  -- Time Dilation (when self-cast)
        370553,  -- Tip the Scales
        390386,  -- Fury of the Aspects
        403631,  -- Augmentation/offensive activation window
        404977,  -- Defensive/hero activation window
        410089,  -- Prescience/self variant when exposed
        410263,  -- Ebon Might/self window variant
        431044,  -- Scalecommander hero activation window
        442204,  -- major hero/offensive window variant
    },
    HUNTER = {
        19574,   -- Bestial Wrath
        186265,  -- Aspect of the Turtle
        186257,  -- Aspect of the Cheetah
        5384,    -- Feign Death
        288613,  -- Trueshot
        53480,   -- Roar of Sacrifice (when self affected)
        264735,  -- Survival of the Fittest
        109304,  -- Exhilaration (if an aura window is exposed)
        260402,  -- Double Tap/variant on builds where present
        360966,  -- Spearhead
        359844,  -- Call of the Wild
        389539,  -- Sentinel/hero activation window
        392956,  -- Fortitude of the Bear
        459731,  -- hero/offensive activation window variant
    },
    MAGE = {
        66,      -- Invisibility
        11426,   -- Ice Barrier
        12042,   -- Arcane Power (older/variant aura)
        12472,   -- Icy Veins
        45438,   -- Ice Block
        55342,   -- Mirror Image
        110960,  -- Greater Invisibility
        190319,  -- Combustion
        235313,  -- Blazing Barrier
        235450,  -- Prismatic Barrier
        342245,  -- Alter Time
        342246,  -- Alter Time aura variant
        365350,  -- Arcane Surge
        383874,  -- Arcane/hero activation window
        389713,  -- Displacement
        414658,  -- Ice Cold / defensive variant
        431177,  -- Sunfury/hero activation window
        444257,  -- Spellslinger/hero activation window
    },
    MONK = {
        115176,  -- Zen Meditation
        115203,  -- Fortifying Brew
        116841,  -- Tiger's Lust
        116849,  -- Life Cocoon (when self-cast)
        122278,  -- Dampen Harm
        122783,  -- Diffuse Magic
        137639,  -- Storm, Earth, and Fire
        152173,  -- Serenity
        243435,  -- Fortifying Brew variant
        322507,  -- Celestial Brew
        325197,  -- Invoke Chi-Ji
        123904,  -- Invoke Xuen
        132578,  -- Invoke Niuzao
        198664,  -- Invoke Yu'lon
        388686,  -- Summon White Tiger Statue / activation window
        392983,  -- Strike of the Windlord/hero self window variant
        451021,  -- Conduit/hero activation window
    },
    PALADIN = {
        498,     -- Divine Protection
        642,     -- Divine Shield
        1022,    -- Blessing of Protection
        1044,    -- Blessing of Freedom
        6940,    -- Blessing of Sacrifice
        31821,   -- Aura Mastery
        31850,   -- Ardent Defender
        31884,   -- Avenging Wrath (Wings)
        86659,   -- Guardian of Ancient Kings
        105809,  -- Holy Avenger
        184662,  -- Shield of Vengeance
        200025,  -- Beacon/major holy activation variant
        205191,  -- Eye for an Eye
        216331,  -- Avenging Crusader
        228049,  -- Guardian/defensive variant
        327193,  -- Moment of Glory
        389539,  -- Sentinel / hero variant when present
        403876,  -- major defensive/hero window
        431416,  -- Lightsmith/hero activation window
    },
    PRIEST = {
        17,      -- Power Word: Shield (self)
        10060,   -- Power Infusion
        33206,   -- Pain Suppression (self)
        47536,   -- Rapture
        47585,   -- Dispersion
        47788,   -- Guardian Spirit (self)
        64843,   -- Divine Hymn channel aura
        194249,  -- Voidform
        200183,  -- Apotheosis
        213602,  -- Greater Fade
        391109,  -- Dark Ascension
        197862,  -- Archangel
        197871,  -- Dark Archangel
        421453,  -- Ultimate Penitence
        428933,  -- defensive shield/hero window
        451235,  -- Oracle/Voidweaver hero activation window
        377065,  -- Mental Fortitude (Midnight Shadow absorb buff)
        391090,  -- Shattered Psyche talent (not always the visible aura)
        391092,  -- Shattered Psyche timed player buff (12.1.x)
        124430,  -- Shadowy Insight proc
        375981,  -- Mind Devourer proc
        390978,  -- Mind Devourer aura variant
        373204,  -- Mindgames/self proc variant
        65081,   -- Body and Soul
        193065,  -- Protective Light
        390636,  -- Protective Light variant
        114255,  -- Surge of Light
        196644,  -- Surge of Light variant
        45242,   -- Focused Will legacy buff
        426401,  -- Focused Will timed player buff (12.1.x)
        47585,   -- Dispersion
        586,     -- Fade
        19236,   -- Desperate Prayer
        21562,   -- Power Word: Fortitude (classified by persistent filter when enabled)
    },
    ROGUE = {
        2983,    -- Sprint
        1856,    -- Vanish
        1966,    -- Feint
        5277,    -- Evasion
        31224,   -- Cloak of Shadows
        13750,   -- Adrenaline Rush
        79140,   -- Vendetta (variant on builds where present)
        121471,  -- Shadow Blades
        185422,  -- Shadow Dance
        343142,  -- Dreadblades
        360194,  -- Deathmark
        381623,  -- Thistle Tea
        385616,  -- Echoing Reprimand/hero window variant
        315341,  -- Between the Eyes activation window variant
        51690,   -- Killing Spree
        114018,  -- Shroud of Concealment
        45182,   -- Cheating Death defensive window
        442726,  -- Fatebound/Deathstalker hero activation window
    },
    SHAMAN = {
        108271,  -- Astral Shift
        79206,   -- Spiritwalker's Grace
        114050,  -- Ascendance (Elemental)
        114051,  -- Ascendance (Restoration)
        114052,  -- Ascendance (Enhancement)
        16166,   -- Elemental Mastery / activation variant
        30823,   -- Shamanistic Rage (variant)
        108280,  -- Healing Tide Totem window if self aura exposed
        108281,  -- Ancestral Guidance
        192249,  -- Storm Elemental
        198067,  -- Fire Elemental
        198103,  -- Earth Elemental
        204366,  -- Thundercharge
        260881,  -- Spirit Wolf defensive window
        381930,  -- Primordial Wave/activation variant
        384352,  -- Doom Winds
        443454,  -- Farseer/Stormbringer hero activation window
    },
    WARLOCK = {
        104773,  -- Unending Resolve
        108416,  -- Dark Pact
        111400,  -- Burning Rush
        113858,  -- Dark Soul: Instability
        113860,  -- Dark Soul: Misery
        48020,   -- Demonic Circle: Teleport speed/window if exposed
        205180,  -- Summon Darkglare activation window
        265187,  -- Summon Demonic Tyrant activation window
        267217,  -- Nether Portal
        386997,  -- Soulburn
        387157,  -- Demonic Strength/activation window
        196098,  -- Soul Harvest (variant)
        212295,  -- Nether Ward
        417537,  -- major hero/offensive window
        445619,  -- Hellcaller/Soul Harvester hero activation window
    },
    WARRIOR = {
        2687,    -- Bloodrage (Classic / Forever)
        20230,   -- Retaliation (Classic / Forever)
        12292,   -- Death Wish (Classic / Forever)
        12328,   -- Sweeping Strikes (Classic / Forever)
        871,     -- Shield Wall
        1719,    -- Recklessness
        18499,   -- Berserker Rage
        23920,   -- Spell Reflection
        12975,   -- Last Stand
        97462,   -- Rallying Cry
        107574,  -- Avatar
        118038,  -- Die by the Sword
        184364,  -- Enraged Regeneration
        198817,  -- Sharpen Blade
        227847,  -- Bladestorm
        46924,   -- Bladestorm (Arms/Fury variant)
        262228,  -- Deadly Calm
        386208,  -- Defensive Stance/activation window variant
        401150,  -- Avatar/hero activation variant
        436358,  -- Mountain Thane/Colossus hero activation window
    },
}

-- Racials / broadly useful activated self buffs. These are intentionally kept
-- separate from class lists and are checked for every character.
local UNIVERSAL_EFFECTS = {
    20572,  -- Blood Fury
    26297,  -- Berserking
    58984,  -- Shadowmeld
    59752,  -- Will to Survive
    7744,   -- Will of the Forsaken
    20594,  -- Stoneform
    20589,  -- Escape Artist (short state on some builds)
    68992,  -- Darkflight
    107079, -- Quaking Palm (state if exposed)
    256948, -- Spatial Rift activation
    255654, -- Bull Rush
    28730,  -- Arcane Torrent variant
    50613,  -- Arcane Torrent variant
    80483,  -- Arcane Torrent variant
    129597, -- Arcane Torrent variant
    155145, -- Arcane Torrent variant
    202719, -- Arcane Torrent variant
    232633, -- Arcane Torrent variant
    25046,  -- Arcane Torrent variant
    69179,  -- Arcane Torrent variant
    312411, -- Bag of Tricks/self window variant
}

local function EnsureDB()
    OmniCC_GODMODE_MidnightSelfCooldownsDB = OmniCC_GODMODE_MidnightSelfCooldownsDB or {}
    db = OmniCC_GODMODE_MidnightSelfCooldownsDB
    for k,v in pairs(defaults) do if db[k] == nil then db[k] = v end end
end

-- Midnight 12.1+ secure aura-display path.
-- IMPORTANT: do not read aura payloads in combat. Blizzard's AuraContainer owns
-- matching, visibility, icon assignment and duration. We only define public
-- spell-ID filters and style the buttons during initializeFrame.
local activeContainer, priorityAuraContainer, stackBonusContainer, fallbackContainer, persistentContainer, longTermContainer, foodPrimaryContainer, foodNearbyContainer, campBenefitsContainer, testOverlay, testIcon, testCD
local activeSpellMap, fallbackSpellMap, helpfulExcludeMap
-- Non-expiring stacking bonus effects sit BELOW timed activated effects, but
-- ABOVE maintenance buffs such as Fortitude and generic permanent auras.
local STACK_BONUS_EFFECTS = {331939} -- Thrill Seeker (visible stacking aura)
local portraitLayer
local portraitGeneration=0
local watchedTPerlPortrait
local selfTestUntil=0

local STRATA_BELOW={BACKGROUND='BACKGROUND',LOW='BACKGROUND',MEDIUM='LOW',HIGH='MEDIUM',DIALOG='HIGH',FULLSCREEN='DIALOG',FULLSCREEN_DIALOG='FULLSCREEN',TOOLTIP='FULLSCREEN_DIALOG'}

-- TPerl compatibility: resolve only a visible, real portrait region. Never
-- reparent or modify TPerl's own portrait or secure unit frames.
local function TPerlPortrait(unit)
    local prefix = unit == 'player' and 'Player' or 'Target'
    -- TPerl's real portrait is frame.portraitFrame. Avoid sparse ipairs lists:
    -- a nil first entry would terminate iteration before reaching TPerl.
    for _,frameName in ipairs({'TPerl_'..prefix, 'XPerl_'..prefix}) do
        local frame = _G[frameName]
        if frame and frame.IsShown and frame:IsShown() then
            local p = frame.portraitFrame or frame.portrait or frame.Portrait
            if p and p.GetParent and p.GetWidth and p.GetHeight
                and p:GetWidth() > 8 and p:GetHeight() > 8
                and (not p.IsShown or p:IsShown()) then
                return p
            end
        end
    end
    return nil
end
-- Custom-frame portrait geometry: the 3D model can be larger than its
-- portrait texture when the unit-frame addon enables Extended Portrait.
-- Never resize the normal portrait from an unrelated unit-frame container.
-- TPerl Extended Portrait can enlarge the displayed 3D model without
-- changing portraitFrame:GetSize(). Find the *visible model's* bounds rather
-- than assuming the original portraitFrame is the complete displayed area.
local function PortraitVisualBounds(portrait)
    local pw,ph=portrait:GetWidth(),portrait:GetHeight()
    if type(pw)~='number' or type(ph)~='number' then return nil,nil end
    local normal=math.max(18,math.floor(math.min(pw,ph)+.5))
    local frame=_G.TPerl_Player or _G.XPerl_Player
    if not (frame and frame.IsShown and frame:IsShown()) then return normal,portrait end
    if (frame.portraitFrame or frame.portrait or frame.Portrait)~=portrait then return normal,portrait end

    -- TPerl extended mode can enlarge a portrait's ART region while leaving
    -- portraitFrame:GetWidth/Height unchanged. Inspect actual visible regions,
    -- not only child frames. This is geometry-only and never changes TPerl UI.
    local bestSize,bestAnchor=normal,portrait
    local okCenter,cx,cy=pcall(function()
        return (portrait:GetLeft()+portrait:GetRight())/2,
               (portrait:GetBottom()+portrait:GetTop())/2
    end)
    if not okCenter or not cx or not cy then return normal,portrait end
    local seen={}
    local function consider(region)
        if not region or seen[region] or not region.GetWidth or not region.GetHeight then return end
        seen[region]=true
        if region.IsShown and not region:IsShown() then return end
        -- Midnight's protected frames may expose secret geometry values.
        -- Validate and compare them entirely within pcall; never leak secrets
        -- into the persistent portrait size or anchor state.
        local ok,size=pcall(function()
            local w,h=region:GetWidth(),region:GetHeight()
            local l,r,b,t=region:GetLeft(),region:GetRight(),region:GetBottom(),region:GetTop()
            if issecretvalue and (issecretvalue(w) or issecretvalue(h)
                or issecretvalue(l) or issecretvalue(r)
                or issecretvalue(b) or issecretvalue(t)) then return nil end
            if type(w)~='number' or type(h)~='number'
                or type(l)~='number' or type(r)~='number'
                or type(b)~='number' or type(t)~='number' then return nil end
            local candidate=math.min(w,h)
            if candidate<=bestSize+2 or candidate>normal*2.1
                or math.max(w,h)>candidate*1.25 then return nil end
            if l<=cx and r>=cx and b<=cy and t>=cy then return candidate end
        end)
        if ok and size and (not issecretvalue or not issecretvalue(size)) then
            bestSize,bestAnchor=size,region
        end
    end
    local function scan(owner,depth)
        if not owner or depth>3 or seen[owner] then return end
        seen[owner]=true
        if owner.GetRegions then
            for _,region in ipairs({owner:GetRegions()}) do consider(region) end
        end
        if owner.GetChildren then
            for _,child in ipairs({owner:GetChildren()}) do
                consider(child)
                scan(child,depth+1)
            end
        end
    end
    scan(portrait,0)
    local parent=portrait.GetParent and portrait:GetParent()
    if parent then scan(parent,0) end
    return math.max(18,math.floor(bestSize+.5)),bestAnchor
end

local function GetPlayerFrame()
    local tp=TPerlPortrait('player')
    return tp and (tp:GetParent() or _G.PlayerFrame) or _G.PlayerFrame
end
local function GetPlayerPortrait()
    local tp=TPerlPortrait('player'); if tp then return tp end
    local pf=GetPlayerFrame()
    if not pf then return _G.PlayerPortrait end
    if pf.PlayerFrameContainer then
        local c=pf.PlayerFrameContainer
        if c.PlayerPortrait then return c.PlayerPortrait end
        if c.Portrait then return c.Portrait end
        if c.PlayerFrameContent and c.PlayerFrameContent.PlayerFrameContentMain then
            local m=c.PlayerFrameContent.PlayerFrameContentMain
            if m.PlayerPortrait then return m.PlayerPortrait end
            if m.Portrait then return m.Portrait end
        end
    end
    return _G.PlayerPortrait or pf.portrait or pf.Portrait
end

local function GetPlayerMask()
    local pf=GetPlayerFrame()
    local c=pf and pf.PlayerFrameContainer
    return c and (c.PlayerPortraitMask or c.PortraitMask) or nil
end

local function SupportsAuraContainer()
    local build=select(4,GetBuildInfo())
    if type(build)=='number' and build < 120100 then return false end
    local ok,f=pcall(CreateFrame,'AuraContainer',nil,UIParent,'CustomAuraContainerTemplate')
    if not ok or not f then return false end
    local yes=type(f.AddAuraGroup)=='function' and type(f.SetUnit)=='function'
    if f.SetEnabled then pcall(f.SetEnabled,f,false) end
    f:Hide()
    return yes
end

local COMMON_HOTS = {
    -- Midnight 12.x healer HoTs / healer-maintenance auras exposed by Blizzard.
    -- Druid
    774,8936,33763,48438,155777,
    -- Priest
    17,139,41635,77489,194384,1253593,
    -- Shaman
    974,383648,61295,
    -- Monk
    115175,119611,124682,450769,
    -- Paladin
    53563,156322,156910,1244893,
    -- Evoker Preservation / Augmentation maintenance effects
    355941,363502,364343,366155,367364,373267,376788,
    360827,395152,410089,410263,410686,413984
}
local FOOD_BUFFS = {
    1229739, -- Welcoming Campfire (Forever 1.60.1)
    -- Shared / legacy food, refreshment, campfire and Well Fed variants.
    7353,7358,57359,327860,340111,454149,
    104280,104281,104282,104283,104284,104285,104286,104287,104288,104289,
    104290,104291,104292,104293,104294,104295,104296,104297,104298,104299,
    -- Forever-only ID is harmless on Midnight and keeps the DB schema unified.
    1283391
}
local LONG_TERM_BUFFS = {
    1229741, -- Camp Benefits: Normal / long-duration buff (NOT Food/Campfire)
    -- Blizzard-published Midnight long-term raid/self buffs.
    1126,1459,6673,21562,369459,462854,474754,
    381732,381741,381746,381748,381749,381750,381751,381752,381753,381754,381756,381757,381758,
    433568,433583,
    -- Rogue poisons / Shaman imbues Blizzard exposes as long-lived maintenance auras.
    2823,8679,3408,5761,315584,381637,381664,
    319773,319778,382021,382022,457496,457481,462757,462742
}
local CAMPFIRE_NEARBY_ID = 1283391
local WELCOMING_CAMPFIRE_ID = 1229739
local function BuildFoodPriorityMaps()
    local benefits, primary, nearby = {}, {}, {}
    if db.showFoodBuffs == true then
        for _,id in ipairs(FOOD_BUFFS) do
            if id == CAMPFIRE_NEARBY_ID then
                nearby[id]=true
            else
                primary[id]=true
            end
        end
    end
    return benefits, primary, nearby
end

local function ParseSpellList(value)
    local out={}
    for token in tostring(value or ''):gmatch('%d+') do local id=tonumber(token); if id then out[id]=true end end
    return out
end

local function BuildSpellMaps()
    local _,classFile=UnitClass('player')
    activeSpellMap={}
    if db.showActivatedEffects ~= false then
        for _,id in ipairs(SELF_EFFECTS[classFile] or {}) do activeSpellMap[id]=true end
        for _,id in ipairs(UNIVERSAL_EFFECTS) do activeSpellMap[id]=true end
    end
    -- Category ownership is authoritative on Midnight.  A spell may exist in a
    -- class/proc table for compatibility, but long buffs, HoTs and food/camp
    -- effects must never leak into Activated / short buffs.
    for _,id in ipairs(LONG_TERM_BUFFS) do activeSpellMap[id]=nil end
    for _,id in ipairs(COMMON_HOTS) do activeSpellMap[id]=nil end
    for _,id in ipairs(FOOD_BUFFS) do activeSpellMap[id]=nil end
    for _,id in ipairs(STACK_BONUS_EFFECTS) do activeSpellMap[id]=nil end

    if db.showHots == true then for _,id in ipairs(COMMON_HOTS) do activeSpellMap[id]=true end end
    -- Food/campfire is rendered by dedicated priority containers below.
    -- Never mix Campfire Nearby into the generic active row.
    -- Always Show is intentionally applied after ownership so an explicit user
    -- override can still force any public spell ID to display.
    for id in pairs(ParseSpellList(db.customAllow)) do activeSpellMap[id]=true end
    for id in pairs(ParseSpellList(db.customBlock)) do activeSpellMap[id]=nil end
    -- Persistent forms/stances are intentionally NOT allowed to beat an
    -- activated cooldown. Shadowform is a low-priority fallback only.
    fallbackSpellMap={}
    -- Specific category ownership beats the broad Normal/Long category.
    -- HoTs and Food/Campfire are never allowed through the generic HELPFUL row;
    -- their own toggles decide whether their dedicated tracked row can show them.
    helpfulExcludeMap={}
    for _,id in ipairs(COMMON_HOTS) do helpfulExcludeMap[id]=true end
    for _,id in ipairs(FOOD_BUFFS) do helpfulExcludeMap[id]=true end
    -- Long-term maintenance buffs have a dedicated layer above the generic
    -- persistent fallback, but below activated procs and shields.
    for _,id in ipairs(LONG_TERM_BUFFS) do helpfulExcludeMap[id]=true end
    for _,id in ipairs(STACK_BONUS_EFFECTS) do helpfulExcludeMap[id]=true end
    for id in pairs(ParseSpellList(db.customBlock)) do helpfulExcludeMap[id]=true end
    if classFile=='PRIEST' then
        fallbackSpellMap[232698]=true -- Shadowform current aura variant
        fallbackSpellMap[15473]=true  -- Shadowform legacy/public spell ID
        activeSpellMap[232698]=nil
        activeSpellMap[15473]=nil
        -- Forms/stances are fallback-only.  Never let the broad HELPFUL row
        -- select Shadowform ahead of Fortitude, food or another real buff.
        helpfulExcludeMap[232698]=true
        helpfulExcludeMap[15473]=true
    end
end

local function MakePortraitLayer(portrait)
    if not portrait or not portrait.GetParent then return nil end
    if TPerlPortrait('player') == portrait then return nil end -- TPerl owns its portrait
    if portraitLayer then return portraitLayer end
    local parent=portrait:GetParent(); if not parent then return nil end
    local okNum,n=pcall(portrait.GetNumPoints,portrait)
    if not okNum or n~=1 then return nil end
    local okDim,w=pcall(portrait.GetWidth,portrait); local okDim2,h=pcall(portrait.GetHeight,portrait)
    if not okDim or not okDim2 or type(w)~='number' or type(h)~='number' then return nil end
    local point,rel,relPoint,x,y=portrait:GetPoint(1); if not point then return nil end
    local layer=CreateFrame('Frame','OmniCC_GODMODE_PlayerPortraitLayer',parent)
    layer:SetAllPoints(parent)
    layer:SetFrameStrata(STRATA_BELOW[parent:GetFrameStrata()] or 'BACKGROUND')
    layer:SetFrameLevel(1)
    portrait:SetParent(layer)
    portrait:ClearAllPoints()
    portrait:SetPoint(point,rel or layer,relPoint or point,x or 0,y or 0)
    portraitLayer=layer
    return layer
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

local function StyleAuraButton(button,mask,width,height)
    button:SetSize(width,height)
    button:SetFlattensRenderLayers(false)
    -- No rectangular opaque backing: it bleeds outside the circular portrait.
    local icon=button:CreateTexture(nil,'ARTWORK',nil,1)
    icon:SetAllPoints(button)
    icon:SetTexCoord(.10,.90,.10,.90)
    if mask and icon.AddMaskTexture then pcall(icon.AddMaskTexture,icon,mask) end
    button:SetIcon(icon)
    local cd=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    cd:SetAllPoints(button); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
    if mask and cd.SetSwipeTexture then cd:SetSwipeTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask') end
    applyNativeAuraSwipe(cd)
    button:SetDurationCooldown(cd)
    -- Native aura buttons may be assigned a different level by the secure layout.
    -- Keep each timer above its OWN icon, never above a higher-priority icon.
    cd:SetFrameStrata(button:GetFrameStrata())
    cd:SetFrameLevel(button:GetFrameLevel()+1)
    ApplyPortraitCountdownTheme(cd)
    button:EnableMouse(false)
end

-- Match the visible portrait border rather than a larger content texture.
-- Only read geometry: never resize or reparent Blizzard/custom border frames.
local function PortraitBorderBounds(portrait)
    local pf=GetPlayerFrame()
    local content=pf and pf.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    local container=pf and pf.PlayerFrameContainer
    local candidates={
        main and main.PortraitBorder, main and main.Border,
        container and container.PortraitBorder, container and container.Border,
        pf and pf.PortraitBorder, pf and pf.portraitBorder,
    }
    -- Custom unit frames may keep their border beside the portrait rather
    -- than on the Blizzard PlayerFrame. Include its immediate owner chain.
    local owner=portrait and portrait.GetParent and portrait:GetParent()
    for depth=1,3 do
        if not owner then break end
        candidates[#candidates+1]=owner.PortraitBorder or owner.portraitBorder
        candidates[#candidates+1]=owner.Border or owner.borderFrame
        if owner.GetParent then owner=owner:GetParent() else break end
    end
    local w,h=portrait:GetWidth(),portrait:GetHeight()
    if type(w)~='number' or type(h)~='number' then return nil,nil,nil end
    local best, bestArea
    for _,border in pairs(candidates) do
        if border and border.GetWidth and border.GetHeight and border~=portrait then
            local ok,bw,bh=pcall(function() return border:GetWidth(),border:GetHeight() end)
            if ok and type(bw)=='number' and type(bh)=='number' and bw>8 and bh>8
                and bw<=w*1.25 and bh<=h*1.25 then
                local area=bw*bh
                if not bestArea or area<bestArea then
                    best,bestArea=border,area
                end
            end
        end
    end
    if best then return math.min(w,best:GetWidth()),math.min(h,best:GetHeight()),best end
    return w,h,nil
end

local function NewPortraitContainer(name,unit,spellMap,levelOffset,excludeMap,extraCandidateFilters)
    local portrait=GetPlayerPortrait(); local pf=GetPlayerFrame(); if not portrait or not pf then return nil end
    local owner=MakePortraitLayer(portrait) or portrait:GetParent() or pf
    local w,h,border=PortraitBorderBounds(portrait); if type(w)~='number' or type(h)~='number' then return nil end
    local portraitW,portraitH=portrait:GetWidth(),portrait:GetHeight()
    local isTPerl=TPerlPortrait('player') == portrait
    -- TPerl's portraitFrame is the actual visible portrait, and Extended
    -- mode changes its geometry. Do not clamp it against a smaller, unrelated
    -- border discovered on the surrounding unit-frame hierarchy.
    if isTPerl then
        w,h=portraitW,portraitH
        if border and border.GetWidth and border.GetHeight then
            local bw,bh=border:GetWidth(),border:GetHeight()
            -- Only a near-matching border can bound this portrait.
            if bw>=portraitW*0.90 and bh>=portraitH*0.90 then
                w,h=math.min(w,bw),math.min(h,bh)
            else
                border=nil
            end
        end
    end
    -- TPerl's Extended Portrait changes portraitFrame HEIGHT, not width.
    -- The old square math.min(width,height) discarded the extra height,
    -- leaving the 3D model visible beneath the aura. Follow TPerl's
    -- actual rectangular portraitFrame, with the same 2px border inset
    -- on every side for both Normal and Extended modes.
    -- Never inspect protected screen-coordinate geometry (Midnight secrets).
    local coverW,coverH
    if isTPerl then
        local ok,pw,ph=pcall(function()
            return portrait:GetWidth(),portrait:GetHeight()
        end)
        if not ok or (issecretvalue and (issecretvalue(pw) or issecretvalue(ph)))
            or type(pw)~='number' or type(ph)~='number' then return nil end
        coverW=math.max(18,math.floor(pw-4+0.5))
        coverH=math.max(18,math.floor(ph-4+0.5))
    else
        local size=math.max(18,math.floor(math.min(w,h)-4+0.5))
        coverW,coverH=size,size
    end
    local visualAnchor=portrait
    portraitGeneration=portraitGeneration+1
    -- Anonymous containers avoid colliding with retired secure frames on OFF/ON.
    local c=CreateFrame('AuraContainer',nil,owner,'CustomAuraContainerTemplate')
    c:Hide(); c:SetSize(coverW,coverH); c:ClearAllPoints()
    local tframe=_G.TPerl_Player or _G.XPerl_Player
    local extendedAnchor=tframe and (tframe.portraitFrame or tframe.portrait or tframe.Portrait)
    if isTPerl and visualAnchor and visualAnchor~=portrait then
        c:SetPoint('CENTER',visualAnchor,'CENTER',0,0)
    else
        c:SetPoint('CENTER',portrait,'CENTER',0,0)
    end
    if c.SetIgnoreParentScale then c:SetIgnoreParentScale(false) end
    c:SetFrameStrata(owner:GetFrameStrata())
    -- Give each category a separated frame-level band. A one-level gap
    -- lets a lower category's cooldown text leak through a higher icon.
    local tier=levelOffset or 2
    local wantedLevel=(owner:GetFrameLevel() or 1)+tier*12
    -- Keep the aura (button + cooldown) below the visible border when its
    -- frame level is accessible. Do not mutate the custom border itself.
    if border and border.GetFrameLevel and border.GetFrameStrata then
        local ok,bl=pcall(border.GetFrameLevel,border)
        local sameStrata=border:GetFrameStrata()==c:GetFrameStrata()
        if ok and sameStrata and type(bl)=='number' and bl>=5 then
            wantedLevel=math.min(wantedLevel,bl-4)
        end
    end
    c:SetFrameLevel(math.max(1,wantedLevel))
    c:SetUnit(unit)
    local filters = (spellMap or excludeMap or extraCandidateFilters) and {includeSpellIDs=spellMap, excludeSpellIDs=excludeMap} or nil
    if filters and extraCandidateFilters then for k,v in pairs(extraCandidateFilters) do filters[k]=v end end
    c:AddAuraGroup(name..'_group_'..portraitGeneration,'HELPFUL',{
        maxFrameCount=1,
        candidateFilters=filters,
        sortMethod=AuraContainerSortMethod and AuraContainerSortMethod.AuraInstanceIDOnly or nil,
        sortDirection=AuraContainerSortDirection and AuraContainerSortDirection.Reverse or nil,
        initializeFrame=function(button)
            -- Secure AuraContainer owns visibility; styling only assigns visual
            -- levels once when the button is created (no combat scans/tickers).
            button:SetFrameStrata(c:GetFrameStrata())
            button:SetFrameLevel(c:GetFrameLevel()+1)
            StyleAuraButton(button,GetPlayerMask(),coverW,coverH)
        end,
        layout={elementWidth=coverW,elementHeight=coverH,elementSpacing=0,lineSpacing=0},
    })
    if c.SetEnabled then c:SetEnabled(true) end
    c:Show()
    -- One authoritative refresh when a filter/container is rebuilt so an aura
    -- that is already active appears immediately after the user enables it.
    if c.UpdateAllAuras then pcall(c.UpdateAllAuras,c) end
    return c
end

local function DestroyContainers()
    local function release(c)
        if not c then return end
        if c.SetUnit then pcall(c.SetUnit,c,nil) end
        if c.SetEnabled then pcall(c.SetEnabled,c,false) end
        c:Hide()
    end
    release(activeContainer); release(stackBonusContainer); release(fallbackContainer); release(persistentContainer); release(longTermContainer)
    release(foodPrimaryContainer); release(foodNearbyContainer); release(campBenefitsContainer)
    activeContainer=nil; priorityAuraContainer=nil; stackBonusContainer=nil; fallbackContainer=nil; persistentContainer=nil; longTermContainer=nil
    foodPrimaryContainer=nil; foodNearbyContainer=nil; campBenefitsContainer=nil
end

local BuildSecureDisplays
local secureRebuildPending=false
-- Watch actual portrait and border geometry, not only TPerl's portrait.
-- All rebuilds are deferred out of combat and coalesced to avoid refresh storms.
local watchedGeometry=setmetatable({}, {__mode='k'})
local geometryRefreshQueued=false
local function QueuePortraitGeometryRefresh()
    if geometryRefreshQueued then return end
    geometryRefreshQueued=true
    C_Timer.After(0.08,function()
        geometryRefreshQueued=false
        if InCombatLockdown and InCombatLockdown() then
            Module._portraitGeometryPending=true
            return
        end
        if db and db.enabled~=false then BuildSecureDisplays() end
    end)
end
local function WatchPortraitGeometry(frame)
    if not frame or watchedGeometry[frame] or not frame.HookScript then return end
    watchedGeometry[frame]=true
    frame:HookScript('OnSizeChanged',QueuePortraitGeometryRefresh)
end

BuildSecureDisplays=function()
    if InCombatLockdown and InCombatLockdown() then secureRebuildPending=true; return false end
    secureRebuildPending=false
    EnsureDB(); BuildSpellMaps(); DestroyContainers()
    if Module._compatSuspended then return false end
    if db.enabled==false or not SupportsAuraContainer() then return false end
    local currentPortrait=GetPlayerPortrait()
    if currentPortrait then
        WatchPortraitGeometry(currentPortrait)
        local pw,ph,detectedBorder=PortraitBorderBounds(currentPortrait)
        WatchPortraitGeometry(detectedBorder)
        -- Extended mode can resize the portrait's immediate owner instead.
        local portraitOwner=currentPortrait.GetParent and currentPortrait:GetParent()
        WatchPortraitGeometry(portraitOwner)
    end
    local tp=TPerlPortrait('player')
    if tp and watchedTPerlPortrait~=tp then
        watchedTPerlPortrait=tp
        -- TPerl resizes its portrait when Extended Portrait is toggled.
        WatchPortraitGeometry(tp)
    end
    -- Fallback first (lower layer), active cooldowns above it. Blizzard drives
    -- both securely in combat; when any active spell exists it visually covers
    -- Shadowform. When it ends, Shadowform is visible again automatically.
    -- Priority (low -> high): fallback form, normal/long buffs,
    -- food/camp benefits, then real activated combat effects.  Shadowform must
    -- never sit above Fortitude/food just because both have long durations.
    if db.showPersistentBuffs == true and next(fallbackSpellMap) then fallbackContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerFallbackAuras','player',fallbackSpellMap,1) end
    if db.showPersistentBuffs == true then
        persistentContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerPersistentAuras','player',nil,2,helpfulExcludeMap)
        -- Dedicated known long/short maintenance buffs (Fortitude, Kings, etc.).
        -- The generic no-duration fallback cannot cover these; activated bonus
        -- effects still sit on level 8 and take precedence over both.
        local longBuffMap={}
        for _,id in ipairs(LONG_TERM_BUFFS) do
            if not ParseSpellList(db.customBlock)[id] then longBuffMap[id]=true end
        end
        if next(longBuffMap) then
            longTermContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerLongTermAuras','player',longBuffMap,3)
        end
    end
    -- Stacking proc without a timer: show only when no timed activated bonus
    -- is visible. This is a separate secure layer; no combat aura polling.
    if db.showActivatedEffects ~= false then
        local stackMap={}
        local blocked=ParseSpellList(db.customBlock)
        for _,id in ipairs(STACK_BONUS_EFFECTS) do
            if not blocked[id] then stackMap[id]=true end
        end
        if next(stackMap) then
            stackBonusContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerStackBonusAuras','player',stackMap,4)
        end
    end
    -- Blizzard's 12.1 native priority classification can recognize class/spec
    -- bonus auras absent from our explicit spell tables. This is a secure
    -- candidate filter: never inspect secret aura data or poll combat auras.
    -- Keep all explicitly tracked effects in the higher tier and exclude
    -- maintenance, HoTs, food and stacking fallbacks from this extra tier.
    if db.showActivatedEffects ~= false then
        local excluded={}
        for id in pairs(activeSpellMap) do excluded[id]=true end
        for _,id in ipairs(LONG_TERM_BUFFS) do excluded[id]=true end
        for _,id in ipairs(COMMON_HOTS) do excluded[id]=true end
        for _,id in ipairs(FOOD_BUFFS) do excluded[id]=true end
        for _,id in ipairs(STACK_BONUS_EFFECTS) do excluded[id]=true end
        for id in pairs(ParseSpellList(db.customBlock)) do excluded[id]=true end
        if select(2,UnitClass('player'))=='PRIEST' then excluded[232698]=true; excluded[15473]=true end
        priorityAuraContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerPriorityBonusAuras','player',nil,8,excluded,{isPriorityAura=true})
    end
    activeContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerActiveAuras','player',activeSpellMap,9)
    -- Same category priority as Forever: real food/camp benefits cover the
    -- low-priority Campfire Nearby proximity aura whenever both are active.
    local campBenefitsMap, foodPrimaryMap, foodNearbyMap = BuildFoodPriorityMaps()
    if next(foodNearbyMap) then foodNearbyContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerCampfireNearby','player',foodNearbyMap,5) end
    if next(foodPrimaryMap) then foodPrimaryContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerFoodBenefits','player',foodPrimaryMap,6) end
    if next(campBenefitsMap) then campBenefitsContainer=NewPortraitContainer('OmniCC_GODMODE_PlayerCampBenefits','player',campBenefitsMap,7) end
    return activeContainer~=nil or priorityAuraContainer~=nil or stackBonusContainer~=nil or foodPrimaryContainer~=nil or foodNearbyContainer~=nil or campBenefitsContainer~=nil
end

local function EnsureTestOverlay()
    local portrait=GetPlayerPortrait(); if not portrait then return nil end
    if testOverlay then return testOverlay end
    local owner=portraitLayer or portrait:GetParent() or UIParent
    testOverlay=CreateFrame('Frame','OmniCC_GODMODE_PlayerPortraitTest',owner)
    testOverlay:SetAllPoints(portrait); testOverlay:SetFrameStrata(owner:GetFrameStrata()); testOverlay:SetFrameLevel((owner:GetFrameLevel() or 1)+1)
    testIcon=testOverlay:CreateTexture(nil,'ARTWORK'); testIcon:SetAllPoints(); testIcon:SetTexCoord(.1,.9,.1,.9)
    local mask=GetPlayerMask(); if mask and testIcon.AddMaskTexture then pcall(testIcon.AddMaskTexture,testIcon,mask) end
    testCD=CreateFrame('Cooldown',nil,testOverlay,'CooldownFrameTemplate'); testCD:SetAllPoints(); testCD:SetDrawEdge(false); testCD:SetDrawBling(false)
    testOverlay:Hide(); return testOverlay
end

function Module:GetDisplayMode()
    EnsureDB()
    if db.enabled == false then return 'OFF' end
    if db.displayMode == 'OFF' then return 'COMBAT' end
    -- CUSTOM is an explicit UI mode.  Do not infer it back into COMBAT/SHORT/ALL
    -- just because its current checkboxes happen to match one of those presets.
    if db.displayMode == 'CUSTOM' then return 'CUSTOM' end
    if db.displayMode then return db.displayMode end
    local a,p,h,f = db.showActivatedEffects ~= false, db.showPersistentBuffs == true, db.showHots == true, db.showFoodBuffs == true
    if a and not p and not h and not f then return 'COMBAT' end
    if a and p and h and f then return 'ALL' end
    if a and not p and h and not f then return 'SHORT' end
    return 'CUSTOM'
end
function Module:SetDisplayMode(mode)
    EnsureDB(); mode=tostring(mode or 'COMBAT'):upper()
    if mode=='OFF' then db.enabled=false
    else
        db.enabled=true
        if mode=='COMBAT' then db.showActivatedEffects=true; db.showPersistentBuffs=false; db.showHots=false; db.showFoodBuffs=false
        elseif mode=='SHORT' then db.showActivatedEffects=true; db.showPersistentBuffs=false; db.showHots=true; db.showFoodBuffs=false
        elseif mode=='ALL' then db.showActivatedEffects=true; db.showPersistentBuffs=true; db.showHots=true; db.showFoodBuffs=true
        elseif mode~='CUSTOM' then mode='COMBAT' end
    end
    db.displayMode=mode
    if not InCombatLockdown or not InCombatLockdown() then BuildSecureDisplays() else secureRebuildPending=true end
end
function Module:GetOption(k) EnsureDB(); return db[k] end
function Module:SetOption(k,v)
    EnsureDB(); db[k]=v
    if k=='enabled' then db.displayMode = v and (db.displayMode=='OFF' and 'COMBAT' or db.displayMode) or 'OFF' end
    if k=='showActivatedEffects' or k=='showPersistentBuffs' or k=='showHots' or k=='showFoodBuffs' then db.displayMode='CUSTOM' end
    if not InCombatLockdown or not InCombatLockdown() then
        BuildSecureDisplays()
        if k=='customBlock' then
            local sf=Addon.MidnightPlayerFrameAuras
            local tf=Addon.MidnightTargetAuraTimers or Addon.MidnightNativeTargetAuras
            if sf and sf.Apply then pcall(sf.Apply,sf) end
            if tf and tf.Apply then pcall(tf.Apply,tf) end
        end
    else
        secureRebuildPending=true
    end
end
function Module:Scan() end -- secure AuraContainer owns live combat refreshes
-- Appearance-only live refresh: native AuraContainer cooldowns can be nested
-- beneath secure aura buttons, not necessarily immediate container children.
local function RefreshPortraitCooldownTree(frame, depth, seen)
 if not frame or depth > 7 or seen[frame] then return end
 seen[frame]=true
 local cd=frame.cooldown or frame.Cooldown
 if frame.GetDurationCooldown then
  local ok, native=pcall(frame.GetDurationCooldown,frame)
  if ok and native then cd=native end
 end
 if cd then ApplyPortraitCountdownTheme(cd) end
 if frame.GetObjectType then
  local ok, kind=pcall(frame.GetObjectType,frame)
  if ok and kind=='Cooldown' then ApplyPortraitCountdownTheme(frame) end
 end
 if frame.GetChildren then
  for _,child in ipairs({frame:GetChildren()}) do
   RefreshPortraitCooldownTree(child,depth+1,seen)
  end
 end
end
function Module:RefreshThemeAppearance()
 local seen={}
 for _,container in ipairs({activeContainer,helpfulContainer,fallbackContainer,persistentContainer,longTermContainer,foodPrimaryContainer,foodNearbyContainer,campBenefitsContainer}) do
  RefreshPortraitCooldownTree(container,0,seen)
 end
 if testCD then ApplyPortraitCountdownTheme(testCD) end
end

function Module:Refresh() if not InCombatLockdown or not InCombatLockdown() then BuildSecureDisplays() else secureRebuildPending=true end end
function Module:Test()
    if not EnsureTestOverlay() then return end
    selfTestUntil=GetTime()+10; testIcon:SetTexture(135875); testCD:SetCooldown(GetTime(),10); testOverlay:Show()
    C_Timer.After(10,function() if testOverlay then testOverlay:Hide() end selfTestUntil=0 end)
end
function Module:Debug()
    local _,classFile=UnitClass('player'); local n=0; for _ in pairs(activeSpellMap or {}) do n=n+1 end
    print(('OmniCC GODMODE Self CDs: secureAuraContainer=%s class=%s tracked=%d activeContainer=%s fallback=%s combat=%s'):format(tostring(SupportsAuraContainer()),tostring(classFile),n,activeContainer and 'YES' or 'NO',fallbackContainer and 'YES' or 'NO',tostring(InCombatLockdown and InCombatLockdown() or false)))
end

Module:RegisterEvent('PLAYER_LOGIN'); Module:RegisterEvent('PLAYER_ENTERING_WORLD'); Module:RegisterEvent('PLAYER_REGEN_ENABLED'); Module:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED'); Module:RegisterEvent('PLAYER_TALENT_UPDATE'); Module:RegisterEvent('SPELLS_CHANGED')
Module:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then C_Timer.After(.5,BuildSecureDisplays)
    elseif event=='PLAYER_REGEN_ENABLED' then
        -- Only complete deferred secure changes. Normal combat exit must not
        -- destroy/recreate portrait aura containers (confirmed Forever lag fix).
        if secureRebuildPending then
            C_Timer.After(0,function()
                if secureRebuildPending then BuildSecureDisplays() end
            end)
        end
    elseif not InCombatLockdown or not InCombatLockdown() then
        C_Timer.After(0,BuildSecureDisplays)
    else
        secureRebuildPending=true
    end
end)
SLASH_OGMSELFCD1='/ogmselfcd'; SlashCmdList.OGMSELFCD=function(msg) msg=(msg or ''):lower(); if msg=='test' then Module:Test() elseif msg=='debug' then Module:Debug() else Module:Refresh() end end
EnsureDB()

-- Complete a queued appearance rebind after combat; never rebuild secure
-- AuraContainers while combat lockdown is active.
Module:HookScript('OnEvent', function(self, event)
 if event == 'PLAYER_REGEN_ENABLED' and self._portraitGeometryPending then self._portraitGeometryPending=nil; QueuePortraitGeometryRefresh() end
 if event == 'PLAYER_REGEN_ENABLED' and self._ogmPortraitThemeRebindPending then
  self._ogmPortraitThemeRebindPending=nil
  if self.Refresh then self:Refresh() end
 end
end)
