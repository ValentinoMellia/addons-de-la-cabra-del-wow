local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

-- Shared Forever combat-aura taxonomy used by GODMODE nameplates and
-- target-portrait effects. Names are intentionally included alongside spell
-- IDs: Forever can remap IDs between builds while the localized aura name
-- remains readable in many contexts.
local Data = {}
Addon.ForeverSpellData = Data
_G.OmniCC_GODMODE_ForeverSpellData = Data

Data.byId = {}
Data.byName = {}
Data.damageById = {}
Data.damageByName = {}
Data.interrupts = {}

local function norm(v)
    if type(v) ~= 'string' then return nil end
    return v:lower():gsub('[%p%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end
Data.NormalizeName = norm

local function add(category, ids, names)
    for _, id in ipairs(ids or {}) do Data.byId[id] = category end
    for _, name in ipairs(names or {}) do
        local n = norm(name)
        if n and n ~= '' then Data.byName[n] = category end
    end
end

local function addDamage(category, ids, names)
    for _, id in ipairs(ids or {}) do Data.damageById[id] = category end
    for _, name in ipairs(names or {}) do
        local n = norm(name)
        if n and n ~= '' then Data.damageByName[n] = category end
    end
end

local function addInterrupt(ids, names)
    for _, id in ipairs(ids or {}) do Data.interrupts[id] = true end
    for _, name in ipairs(names or {}) do
        local n = norm(name)
        if n and n ~= '' then Data.byName[n] = 'INTERRUPT' end
    end
end

-- Hard crowd control -------------------------------------------------------
add('STUN', {
    853, 408, 1833, 5211, 22570, 20549, 30283, 46968, 107570, 119381,
    132168, 132169, 108194, 91800, 91807, 89766, 1776, 199085, 211881,
    221562, 24394, 91797, 287254, 179057, 213491, 205630, 117526,
    357210, 368970, 372245, 377048, 385954, 401150, 405233, 425701,
}, {
    'Hammer of Justice','Kidney Shot','Cheap Shot','Bash','Maim','War Stomp',
    'Shadowfury','Shockwave','Storm Bolt','Leg Sweep','Fists of Fury',
    'Asphyxiate','Gnaw','Holy Wrath','Intimidation','Capacitor Totem',
    'Axe Toss','Chaos Nova','Mighty Bash','Fel Eruption','Lightning Lasso',
    'Binding Shot','Deep Freeze','Dragon Roar','Skull Bash Stun','Static Charge',
    'Infernal Awakening','Blinding Sleet','Felblade Stun','Landslide Stun',
})

add('FEAR', {
    5782, 5484, 8122, 5246, 1513, 2094, 6358, 31661, 207167, 207685,
    118699, 261589, 10326, 6789, 87204, 33786, 605, 20066,
}, {
    'Fear','Howl of Terror','Psychic Scream','Intimidating Shout','Scare Beast',
    'Seduction','Mortal Coil','Death Coil','Terrify','Turn Evil','Sigil of Misery',
    'Mind Control','Dominate Mind','Horrify','Frightened','Roar of Sacrifice Fear',
})

add('ROOT', {
    339, 1062, 5195, 5196, 9852, 9853, 122, 865, 6131, 10230, 33395, 64695, 102359, 116706, 198121, 204085, 212638,
    233395, 356738, 378760, 399786, 45334, 96294, 19185, 117526,
    236077, 285515, 356356, 394061, 408544,
}, {
    'Entangling Roots','Frost Nova','Freeze','Earthgrab','Earthgrab Totem',
    'Mass Entanglement','Disable','Ice Nova','Steel Trap','Binding Shot',
    'Void Tendrils','Entrapment','Web','Chains of Ice','Grasping Earth',
    'Charged Earth','Frozen in Place','Sticky Tar Bomb','Pinning',
})

add('SILENCE', {
    15487, 1330, 47476, 204490, 31935, 19647, 78675, 202933, 217832,
    28730, 81261, 356727, 410065, 374776, 360806, 410126,
}, {
    'Silence','Garrote - Silence','Strangulate','Spell Lock','Solar Beam',
    'Avenger\'s Shield Silence','Arcane Torrent','Sigil of Silence',
    'Spear Hand Strike Silence','Improved Counterspell','Counterspell Silence',
    'Wailing Arrow Silence','Oppressing Roar Silence','Suffocating Darkness',
})

add('INCAP', {
    118, 28271, 28272, 61721, 61780, 6770, 2070, 20066, 3355, 710,
    115078, 217832, 31661, 82691, 105421, 99, 2637, 2094, 1776,
    221527, 277778, 383121, 360806, 357214, 372048, 207171, 211004,
}, {
    'Polymorph','Sap','Gouge','Blind','Freezing Trap','Repentance','Hibernate',
    'Wyvern Sting','Banish','Cyclone','Scatter Shot','Dragon\'s Breath',
    'Paralysis','Ring of Frost','Blinding Light','Incapacitating Roar',
    'Imprison','Hex','Shackle Undead','Song of Chi-Ji','Sleep Walk','Mind Soothe',
    'Mesmerize','Sigil of Chains Incapacitate','Walk the Plank','Polymorph: Fish',
})

add('DISARM', {
    676, 51722, 233759, 209749, 236077, 207777, 202138, 327814, 409560,
}, {
    'Disarm','Dismantle','Grapple Weapon','Clawing Shadows Disarm','Weapon Snatch',
    'Riposte Disarm','Psychic Horror Disarm','Talon Rend Disarm',
})

-- Soft control / utility ---------------------------------------------------
add('SLOW', {
    1715, 7372, 7373, 25212, 12323, 12324, 12325, 116, 31589, 120, 45524, 3409, 18223, 58180, 3600,
    5116, 8056, 8058, 10472, 10473, 25464, 135299, 61391, 121253, 196840, 204263, 198813, 206760, 356356,
    391140, 393951, 410873, 431380,
}, {
    'Hamstring','Piercing Howl','Frostbolt','Slow','Cone of Cold','Chains of Ice',
    'Crippling Poison','Curse of Exhaustion','Frost Shock','Earthbind',
    'Concussive Shot','Wing Clip','Thunder Clap','Hand of Hindrance','Tar Trap',
    'Chilblains','Razor Fragments Slow','Disable Slow','Mind Flay Slow',
    'Sticky Tar','Frigid Wind','Icy Shards Slow','Grasping Vines Slow',
})

add('UTILITY', {
    1130, 257284, 147362, 19801, 55078, 55095, 207203, 356995, 360194,
}, {
    'Hunter\'s Mark','Flare','Arcane Shot Mark','Purge the Wicked Mark',
    'Death and Decay Snare','Frost Fever Utility','Blood Plague Utility',
    'Marked for Death','Sentinel Mark','Prey on the Weak',
})

-- Taunts / healing reduction ----------------------------------------------
add('TAUNT', {355, 6795, 62124, 56222, 116189, 185245, 49560, 2649, 20736, 17735}, {
    'Taunt','Growl','Hand of Reckoning','Dark Command','Provoke','Torment','Command Demon Taunt'
})
add('HEALREDUCE', {12294, 8680, 115804, 54680, 197214, 236077, 198590, 390179}, {
    'Mortal Wounds','Mortal Strike','Wound Poison','Widow Venom','Necrotic Wound',
    'Sharpen Blade','Hemotoxin','Psyfiend Healing Reduction'
})

-- Major immunities / defensives -------------------------------------------
add('IMMUNITY', {
    642, 45438, 1022, 1044, 31224, 19263, 186265, 196555, 204018, 23920,
    48707, 48792, 212800, 122470, 122783, 198589, 363916, 374348, 383762,
}, {
    'Divine Shield','Ice Block','Blessing of Protection','Blessing of Freedom',
    'Cloak of Shadows','Aspect of the Turtle','Netherwalk','Blessing of Spellwarding',
    'Spell Reflection','Anti-Magic Shell','Anti-Magic Zone','Blur Immunity',
    'Diffuse Magic','Dampen Harm','Obsidian Scales','Renewing Blaze','Nullifying Shroud'
})

add('DAMAGE_REDUCTION', {
    498, 871, 22812, 33206, 30823, 47585, 61336, 48792, 55233, 102342,
    108271, 122278, 122783, 115203, 118038, 184364, 198589, 212800, 363916,
    374348, 385450, 386208, 403876, 404977, 45182,
}, {
    'Divine Protection','Shield Wall','Barkskin','Pain Suppression','Shamanistic Rage',
    'Dispersion','Survival Instincts','Icebound Fortitude','Vampiric Blood',
    'Ironbark','Astral Shift','Fortifying Brew','Dampen Harm','Die by the Sword',
    'Enraged Regeneration','Blur','Crimson Vial','Obsidian Scales','Renewing Blaze',
    'Darkness','Evasion','Fortified by Nature','Protective Growth','Stoneform',
})

add('ABSORPTION', {
    17, 11426, 48707, 77535, 207472, 235450, 47753, 152118, 184662, 108366,
    198065, 386614, 392956, 414658, 428933,
}, {
    'Power Word: Shield','Ice Barrier','Anti-Magic Shell','Blood Shield',
    'Celestial Brew','Life Cocoon','Divine Aegis','Soul Leech','Prismatic Barrier',
    'Ignore Pain','Earth Shield Absorb','Blazing Barrier','Illuminated Healing',
})

add('DEFENSIVE', {
    5277, 12975, 31850, 31821, 108416, 104773, 1044, 1022, 6940, 199754,
    116849, 108271, 122278, 122783, 115203, 49028, 55233, 194679, 363916,
    374348, 403876, 404977, 45182, 1966, 31224, 61336,
}, {
    'Evasion','Last Stand','Ardent Defender','Aura Mastery','Dark Pact',
    'Unending Resolve','Blessing of Sacrifice','Blessing of Sanctuary','Life Cocoon',
    'Astral Shift','Dampen Harm','Diffuse Magic','Fortifying Brew','Dancing Rune Weapon',
    'Vampiric Blood','Rune Tap','Obsidian Scales','Renewing Blaze','Feint',
})

add('OFFENSIVE', {
    1719, 31884, 10060, 12472, 12042, 16166, 13750, 3045, 19574, 79140,
    51271, 152173, 113858, 113860, 194223, 106951, 102543, 102560, 191427,
    198067, 137639, 152277, 228260, 375087, 403631, 381623, 390386, 442204,
}, {
    'Recklessness','Avenging Wrath','Power Infusion','Icy Veins','Arcane Power',
    'Elemental Mastery','Adrenaline Rush','Rapid Fire','Bestial Wrath','Vendetta',
    'Pillar of Frost','Storm, Earth, and Fire','Dark Soul: Instability',
    'Dark Soul: Misery','Celestial Alignment','Berserk','Incarnation: King of the Jungle',
    'Incarnation: Chosen of Elune','Metamorphosis','Ascendance','Serenity',
    'Combustion','Trueshot','Breath of Sindragosa','Dragonrage','Tip the Scales',
    'The Hunt','Deathmark','Avatar','Coordinated Assault','Voidform','Shadow Blades',
})

-- Interrupt families -------------------------------------------------------
addInterrupt({
    1766, 6552, 2139, 19647, 57994, 47528, 96231, 106839, 116705, 183752,
    147362, 351338, 187707, 78675, 119910, 97547, 91802, 132409,
}, {
    'Kick','Pummel','Counterspell','Spell Lock','Wind Shear','Mind Freeze',
    'Rebuke','Skull Bash','Spear Hand Strike','Disrupt','Counter Shot',
    'Quell','Muzzle','Solar Beam Interrupt','Optical Blast','Silence Interrupt',
})

-- Damage-over-time families. These are optional for the portrait tracker and
-- classify nameplate auras when Custom/All filters are used.
addDamage('BLEED', {
    1943, 703, 1079, 1822, 772, 16511, 121411, 77758, 155722, 202028,
    274838, 285514, 391356, 385060, 394036, 405233,
}, {
    'Rupture','Garrote','Rip','Rake','Rend','Hemorrhage','Deep Wounds',
    'Crimson Tempest','Thrash','Lacerate','Internal Bleeding','Bloodseeker',
    'Serrated Bone Spike','Exsanguinated','Gushing Wound','Tear Open Wounds',
})

addDamage('DOT', {
    172, 980, 348, 30108, 157736, 603, 589, 34914, 2944, 15407, 55078,
    55095, 55078, 55095, 191587, 164812, 164815, 188389, 188443, 1978,
    271788, 257284, 212431, 217200, 205179, 204213, 146739, 26573,
    204242, 115181, 124280, 123725, 325733, 356995, 359077, 370898,
    410598, 409472, 442624, 443740,
}, {
    'Corruption','Agony','Immolate','Unstable Affliction','Doom','Shadow Word: Pain',
    'Vampiric Touch','Devouring Plague','Mind Flay','Blood Plague','Frost Fever',
    'Virulent Plague','Moonfire','Sunfire','Flame Shock','Serpent Sting',
    'Wildfire Bomb','Black Arrow','Explosive Shot','A Murder of Crows','Stellar Flare',
    'Consecration','Breath of Fire','Touch of Karma','Touch of Death','The Hunt',
    'Soul Rot','Phantom Singularity','Wither','Disintegrate','Fire Breath','Dream Breath',
    'Eternity Surge Dot','Pyre Dot','Shadowflame','Living Bomb','Ignite','Frost Bomb',
})

local damagePrefixes = {
    'garrote','rupture','rake','rip','rend','thrash','deep wound','hemorrhage',
    'crimson tempest','corruption','agony','immolate','unstable affliction','doom',
    'shadow word pain','vampiric touch','devouring plague','moonfire','sunfire',
    'flame shock','serpent sting','black arrow','explosive shot','wildfire bomb',
    'blood plague','frost fever','virulent plague','breath of fire','living bomb',
    'ignite','frost bomb','soul rot','phantom singularity','stellar flare','withering',
}

function Data.Category(spellId, name)
    local id = tonumber(spellId)
    if id and Data.interrupts[id] then return 'INTERRUPT' end
    if id and Data.byId[id] then return Data.byId[id] end
    local n = norm(name)
    if n and Data.byName[n] then return Data.byName[n] end
    return nil
end

function Data.DamageCategory(spellId, name)
    local id = tonumber(spellId)
    if id and Data.damageById[id] then return Data.damageById[id] end
    local n = norm(name)
    if n and Data.damageByName[n] then return Data.damageByName[n] end
    if n then
        for _, prefix in ipairs(damagePrefixes) do
            if n:find(prefix, 1, true) == 1 then
                if prefix=='garrote' or prefix=='rupture' or prefix=='rake' or prefix=='rip' or prefix=='rend' or prefix=='thrash' or prefix=='deep wound' or prefix=='hemorrhage' or prefix=='crimson tempest' then
                    return 'BLEED'
                end
                return 'DOT'
            end
        end
    end
    return nil
end

Data.priority = {
    STUN=1000, INCAP=950, FEAR=900, SILENCE=850, DISARM=800,
    ROOT=750, SLOW=700, INTERRUPT=650, HEALREDUCE=625, TAUNT=600,
    AURA=500, BLEED=300, DOT=250, UTILITY=100,
}
