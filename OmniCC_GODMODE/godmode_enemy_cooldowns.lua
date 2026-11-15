-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
local _, Addon = ...
local iface = select(4, GetBuildInfo()) or 0
if iface ~= 16001 and iface < 120000 then return end

local KEY = iface == 16001 and 'OmniCC_GODMODE_ForeverEnemyCDDB' or 'OmniCC_GODMODE_MidnightEnemyCDDB'
local TARGET_DEFAULT_X, TARGET_DEFAULT_Y, TARGET_DEFAULT_ANCHOR = 0, 10, 'BOTTOM'
local defaults = {enabled=true, enemy=true, friendly=true, sounds=false, iconSize=30, spacing=4, interrupts=true, defensives=true, offensives=true, cc=true, mobility=true, targetEnabled=true, nameplateEnabled=true, targetMouseover=true, targetIconSize=30, targetSpacing=4, targetPerRow=8, targetMaxIcons=16, targetMinCD=0, targetX=TARGET_DEFAULT_X, targetY=TARGET_DEFAULT_Y, targetAnchor=TARGET_DEFAULT_ANCHOR, targetGrowth='RIGHT', targetRowGrowth='UP', targetSort='TIME'}

-- Player cooldown knowledge.  This is deliberately a known-duration table: when the client
-- exposes a successful cast to addons we can predict when that ability is available again.
-- Midnight/Forever may mark casts secret; secret values are NEVER inspected or used as keys.
local spells = {
 -- DEATH KNIGHT
 [48707]={60,'DEF'},       -- Anti-Magic Shell
 [48792]={120,'DEF'},      -- Icebound Fortitude
 [49028]={120,'DEF'},      -- Dancing Rune Weapon
 [51271]={60,'OFF'},       -- Pillar of Frost
 [55233]={90,'DEF'},       -- Vampiric Blood
 [47568]={120,'OFF'},      -- Empower Rune Weapon
 [49039]={120,'DEF'},      -- Lichborne
 [207289]={90,'OFF'},      -- Unholy Assault

 -- DEMON HUNTER
 [191427]={180,'OFF'},     -- Metamorphosis (Havoc)
 [187827]={180,'OFF'},     -- Metamorphosis (Vengeance aura)
 [198589]={60,'DEF'},      -- Blur
 [196555]={180,'DEF'},     -- Netherwalk
 [188501]={30,'MOB'},      -- Spectral Sight
 [196718]={180,'DEF'},     -- Darkness
 [206803]={60,'OFF'},      -- Rain from Above

 -- DRUID
 [1850]={120,'MOB'},       -- Dash
 [252216]={45,'MOB'},      -- Tiger Dash
 [22812]={60,'DEF'},       -- Barkskin
 [61336]={180,'DEF'},      -- Survival Instincts
 [106898]={120,'MOB'},     -- Stampeding Roar
 [106951]={180,'OFF'},     -- Berserk
 [102543]={180,'OFF'},     -- Incarnation: King of the Jungle
 [102558]={180,'OFF'},     -- Incarnation: Guardian of Ursoc
 [102560]={180,'OFF'},     -- Incarnation: Chosen of Elune
 [33891]={180,'OFF'},      -- Incarnation: Tree of Life
 [194223]={120,'OFF'},     -- Celestial Alignment
 [29166]={180,'OFF'},      -- Innervate
 [102342]={90,'DEF'},      -- Ironbark

 -- EVOKER
 [363916]={90,'DEF'},      -- Obsidian Scales
 [374348]={90,'DEF'},      -- Renewing Blaze
 [375087]={120,'OFF'},     -- Dragonrage
 [370960]={180,'DEF'},     -- Emerald Communion
 [374227]={120,'DEF'},     -- Zephyr
 [378464]={120,'MOB'},     -- Time Spiral
 [357170]={60,'DEF'},      -- Time Dilation
 [370553]={120,'OFF'},     -- Tip the Scales
 [390386]={300,'OFF'},     -- Fury of the Aspects

 -- HUNTER
 [19574]={90,'OFF'},       -- Bestial Wrath
 [186265]={180,'DEF'},     -- Aspect of the Turtle
 [186257]={180,'MOB'},     -- Aspect of the Cheetah
 [5384]={30,'DEF'},        -- Feign Death
 [288613]={120,'OFF'},     -- Trueshot
 [53480]={60,'DEF'},       -- Roar of Sacrifice
 [264735]={180,'DEF'},     -- Survival of the Fittest
 [392956]={120,'DEF'},     -- Fortitude of the Bear
 [360966]={120,'OFF'},     -- Spearhead
 [359844]={120,'OFF'},     -- Call of the Wild

 -- MAGE
 [66]={300,'DEF'},         -- Invisibility
 [110960]={120,'DEF'},     -- Greater Invisibility
 [11426]={25,'DEF'},       -- Ice Barrier
 [12472]={120,'OFF'},      -- Icy Veins
 [45438]={240,'DEF'},      -- Ice Block
 [55342]={120,'DEF'},      -- Mirror Image
 [190319]={120,'OFF'},     -- Combustion
 [235313]={25,'DEF'},      -- Blazing Barrier
 [235450]={25,'DEF'},      -- Prismatic Barrier
 [342245]={60,'DEF'},      -- Alter Time
 [342246]={60,'DEF'},      -- Alter Time aura variant
 [365350]={90,'OFF'},      -- Arcane Surge
 [414658]={240,'DEF'},     -- Ice Cold

 -- MONK
 [115176]={300,'DEF'},     -- Zen Meditation
 [115203]={360,'DEF'},     -- Fortifying Brew
 [243435]={360,'DEF'},     -- Fortifying Brew aura variant
 [116841]={30,'MOB'},      -- Tiger's Lust
 [116849]={120,'DEF'},     -- Life Cocoon
 [122278]={120,'DEF'},     -- Dampen Harm
 [122783]={90,'DEF'},      -- Diffuse Magic
 [137639]={90,'OFF'},      -- Storm, Earth, and Fire
 [152173]={90,'OFF'},      -- Serenity
 [322507]={60,'DEF'},      -- Celestial Brew
 [123904]={120,'OFF'},     -- Invoke Xuen
 [132578]={180,'DEF'},     -- Invoke Niuzao
 [198664]={180,'OFF'},     -- Invoke Yu'lon
 [325197]={180,'OFF'},     -- Invoke Chi-Ji

 -- PALADIN
 [498]={60,'DEF'},         -- Divine Protection
 [642]={300,'DEF'},        -- Divine Shield
 [1022]={300,'DEF'},       -- Blessing of Protection
 [1044]={25,'MOB'},        -- Blessing of Freedom
 [6940]={120,'DEF'},       -- Blessing of Sacrifice
 [31821]={180,'DEF'},      -- Aura Mastery
 [31850]={120,'DEF'},      -- Ardent Defender
 [31884]={120,'OFF'},      -- Avenging Wrath
 [86659]={300,'DEF'},      -- Guardian of Ancient Kings
 [105809]={120,'OFF'},     -- Holy Avenger
 [184662]={120,'DEF'},     -- Shield of Vengeance
 [205191]={60,'DEF'},      -- Eye for an Eye
 [216331]={120,'OFF'},     -- Avenging Crusader
 [327193]={120,'DEF'},     -- Moment of Glory

 -- PRIEST
 [17]={7.5,'DEF'},         -- Power Word: Shield (observable self shield; short recast)
 [10060]={120,'OFF'},      -- Power Infusion
 [33206]={180,'DEF'},      -- Pain Suppression
 [47536]={90,'OFF'},       -- Rapture
 [47585]={120,'DEF'},      -- Dispersion
 [47788]={180,'DEF'},      -- Guardian Spirit
 [194249]={120,'OFF'},     -- Voidform
 [200183]={120,'OFF'},     -- Apotheosis
 [213602]={30,'DEF'},      -- Greater Fade
 [391109]={60,'OFF'},      -- Dark Ascension
 [421453]={240,'OFF'},     -- Ultimate Penitence
 [19236]={90,'DEF'},       -- Desperate Prayer

 -- ROGUE
 [2983]={120,'MOB'},       -- Sprint
 [1856]={120,'DEF'},       -- Vanish
 [1966]={15,'DEF'},        -- Feint
 [5277]={120,'DEF'},       -- Evasion
 [31224]={120,'DEF'},      -- Cloak of Shadows
 [13750]={180,'OFF'},      -- Adrenaline Rush
 [121471]={120,'OFF'},     -- Shadow Blades
 [185422]={60,'OFF'},      -- Shadow Dance
 [343142]={90,'OFF'},      -- Dreadblades
 [360194]={120,'OFF'},     -- Deathmark
 [381623]={60,'OFF'},      -- Thistle Tea
 [51690]={120,'OFF'},      -- Killing Spree
 [114018]={360,'DEF'},     -- Shroud of Concealment

 -- SHAMAN
 [108271]={90,'DEF'},      -- Astral Shift
 [79206]={120,'MOB'},      -- Spiritwalker's Grace
 [114050]={180,'OFF'},     -- Ascendance (Elemental)
 [114051]={180,'OFF'},     -- Ascendance (Restoration)
 [114052]={180,'OFF'},     -- Ascendance (Enhancement)
 [30823]={60,'DEF'},       -- Shamanistic Rage / variant
 [108281]={120,'DEF'},     -- Ancestral Guidance
 [204366]={45,'DEF'},      -- Thundercharge
 [384352]={60,'OFF'},      -- Doom Winds

 -- WARLOCK
 [104773]={180,'DEF'},     -- Unending Resolve
 [108416]={60,'DEF'},      -- Dark Pact
 [111400]={1,'MOB'},       -- Burning Rush toggle; aura detection only effectively
 [113858]={120,'OFF'},     -- Dark Soul: Instability
 [113860]={120,'OFF'},     -- Dark Soul: Misery
 [212295]={45,'DEF'},      -- Nether Ward
 [386997]={30,'OFF'},      -- Soulburn

 -- WARRIOR (Forever + Midnight; includes Classic-era activations)
 [2687]={60,'OFF'},        -- Bloodrage (Forever/Classic)
 [20230]={1800,'DEF'},     -- Retaliation (Forever/Classic)
 [12292]={180,'OFF'},      -- Death Wish (Forever/Classic)
 [12328]={30,'OFF'},       -- Sweeping Strikes (Forever/Classic)
 [871]={240,'DEF'},        -- Shield Wall
 [1719]={90,'OFF'},        -- Recklessness
 [18499]={60,'DEF'},       -- Berserker Rage
 [23920]={25,'DEF'},       -- Spell Reflection
 [12975]={180,'DEF'},      -- Last Stand
 [97462]={180,'DEF'},      -- Rallying Cry
 [107574]={90,'OFF'},      -- Avatar
 [118038]={120,'DEF'},     -- Die by the Sword
 [184364]={120,'DEF'},     -- Enraged Regeneration
 [198817]={25,'OFF'},      -- Sharpen Blade
 [227847]={90,'OFF'},      -- Bladestorm
 [46924]={90,'OFF'},       -- Bladestorm variant

 -- RACIAL / UNIVERSAL OBSERVABLE SELF BUFFS
 [20572]={120,'OFF'},      -- Blood Fury
 [26297]={180,'OFF'},      -- Berserking
 [58984]={120,'DEF'},      -- Shadowmeld
 [59752]={180,'DEF'},      -- Will to Survive
 [7744]={120,'DEF'},       -- Will of the Forsaken
 [20594]={120,'DEF'},      -- Stoneform
 [68992]={120,'MOB'},      -- Darkflight

 -- Interrupt/CC knowledge retained for later observable-cast source. Current target-aura
 -- observer does NOT fire these unless Blizzard exposes a matching helpful self aura.
 [1766]={15,'INT'}, [6552]={15,'INT'}, [2139]={24,'INT'}, [47528]={15,'INT'}, [57994]={12,'INT'}, [96231]={15,'INT'}, [106839]={15,'INT'}, [116705]={15,'INT'}, [147362]={24,'INT'}, [183752]={15,'INT'}, [187707]={15,'INT'},
 [408]={20,'CC'}, [853]={60,'CC'}, [5211]={60,'CC'}, [8122]={60,'CC'}, [2094]={120,'CC'}, [51514]={30,'CC'}, [118]={30,'CC'}, [33786]={60,'CC'}, [5246]={90,'CC'}, [179057]={60,'CC'}, [211004]={45,'CC'}, [221562]={45,'CC'},
 [1953]={15,'MOB'}, [100]={20,'MOB'}, [36554]={30,'MOB'},
}


-- Client-specific important cooldown expansion.  Keep the renderer/detectors shared, but
-- NEVER share cooldown durations between Forever and Midnight: the same spell ID can have
-- radically different cooldowns (e.g. Recklessness).
if iface == 16001 then
 spells = {
  -- WARRIOR (Forever/Classic)
  [2687]={60,'OFF'}, [29131]={60,'OFF'}, -- Bloodrage cast + triggered aura
  [1719]={1800,'OFF'}, [20230]={1800,'DEF'}, [871]={1800,'DEF'},
  [12292]={180,'OFF'}, [12328]={30,'OFF'}, [12975]={600,'DEF'}, [18499]={30,'DEF'},
  [6552]={10,'INT'}, [72]={12,'INT'}, [5246]={180,'CC'}, [100]={15,'MOB'},
  -- MAGE
  [45438]={300,'DEF'}, [2139]={30,'INT'}, [1953]={15,'MOB'}, [122]={25,'CC'},
  [12042]={180,'OFF'}, [12043]={180,'OFF'}, [11958]={600,'DEF'}, [12051]={480,'OFF'},
  [12472]={180,'OFF'}, [11129]={180,'OFF'}, [66]={300,'DEF'},
  -- ROGUE
  [5277]={300,'DEF'}, [2983]={300,'MOB'}, [1856]={300,'DEF'}, [1766]={10,'INT'},
  [2094]={300,'CC'}, [14185]={600,'DEF'}, [13750]={300,'OFF'}, [13877]={120,'OFF'},
  [14177]={180,'OFF'}, [14183]={180,'OFF'},
  -- PRIEST
  [8122]={30,'CC'}, [15487]={45,'INT'}, [10060]={180,'OFF'}, [14751]={180,'OFF'},
  [19236]={600,'DEF'}, [6346]={30,'DEF'},
  -- PALADIN
  [642]={300,'DEF'}, [1020]={300,'DEF'}, [1022]={300,'DEF'}, [5599]={300,'DEF'}, [10278]={300,'DEF'},
  [853]={60,'CC'}, [20066]={60,'CC'}, [20216]={120,'OFF'}, [633]={3600,'DEF'},
  -- HUNTER
  [5384]={30,'DEF'}, [19574]={120,'OFF'}, [19263]={300,'DEF'}, [1499]={30,'CC'},
  [1543]={20,'DEF'}, [3045]={300,'OFF'}, [19386]={60,'CC'},
  -- DRUID
  [22812]={60,'DEF'}, [1850]={300,'MOB'}, [5211]={60,'CC'}, [29166]={360,'OFF'},
  [17116]={180,'OFF'}, [16689]={60,'DEF'}, [22842]={180,'DEF'},
  -- SHAMAN
  [16188]={180,'OFF'}, [16166]={180,'OFF'}, [16190]={300,'OFF'}, [20608]={3600,'DEF'},
  [8177]={15,'DEF'}, [2484]={15,'CC'},
  -- WARLOCK
  [17928]={40,'CC'}, [5484]={40,'CC'}, [6789]={120,'DEF'}, [18708]={900,'DEF'},
  -- RACIALS
  [1259416]={120,'MOB'}, -- Walk on Air (Skyborne, Forever)
  [1259705]={120,'OFF'}, -- Read Ley Line (High Order Skyborne, Forever)
  [20572]={120,'OFF'}, [26297]={180,'OFF'}, [7744]={120,'DEF'}, [20594]={180,'DEF'}, [20600]={180,'DEF'},
 }
 -- FULL SHORT-COOLDOWN EXPANSION (Forever). Database only: do not touch the locked
 -- nameplate/AuraContainer governor. Rank-specific Classic IDs are included because
 -- UNIT_SPELLCAST_SUCCEEDED can report the learned rank rather than rank 1.
 local shortCD = {
  -- WARRIOR
  [355]={10,'CC'}, -- Taunt
  [6343]={4,'OFF'},[8198]={4,'OFF'},[8204]={4,'OFF'},[8205]={4,'OFF'},[11580]={4,'OFF'},[11581]={4,'OFF'}, -- Thunder Clap ranks
  [2565]={5,'DEF'}, -- Shield Block
  [72]={12,'INT'},[1671]={12,'INT'},[1672]={12,'INT'}, -- Shield Bash ranks
  [676]={60,'CC'}, -- Disarm
  [100]={15,'MOB'},[6178]={15,'MOB'},[11578]={15,'MOB'}, -- Charge ranks
  [20252]={30,'MOB'},[20616]={30,'MOB'},[20617]={30,'MOB'}, -- Intercept ranks
  [1161]={600,'CC'}, -- Challenging Shout
  [694]={120,'CC'},[7400]={120,'CC'},[7402]={120,'CC'},[20559]={120,'CC'},[20560]={120,'CC'},[25266]={120,'CC'}, -- Mocking Blow ranks
  [7384]={5,'OFF'},[7887]={5,'OFF'},[11584]={5,'OFF'},[11585]={5,'OFF'}, -- Overpower ranks
  [1680]={10,'OFF'}, -- Whirlwind
  [12294]={6,'OFF'},[21551]={6,'OFF'},[21552]={6,'OFF'},[21553]={6,'OFF'}, -- Mortal Strike ranks
  [23881]={6,'OFF'},[23892]={6,'OFF'},[23893]={6,'OFF'},[23894]={6,'OFF'}, -- Bloodthirst ranks
  -- MAGE
  [122]={25,'CC'},[865]={25,'CC'},[6131]={25,'CC'},[10230]={25,'CC'}, -- Frost Nova ranks
  [120]={10,'CC'},[8492]={10,'CC'},[10159]={10,'CC'},[10160]={10,'CC'},[10161]={10,'CC'}, -- Cone of Cold ranks
  [2136]={8,'OFF'},[2137]={8,'OFF'},[2138]={8,'OFF'},[8412]={8,'OFF'},[8413]={8,'OFF'},[10197]={8,'OFF'},[10199]={8,'OFF'}, -- Fire Blast ranks
  [11113]={45,'CC'},[13018]={45,'CC'},[13019]={45,'CC'},[13020]={45,'CC'},[13021]={45,'CC'}, -- Blast Wave ranks
  [11426]={30,'DEF'},[13031]={30,'DEF'},[13032]={30,'DEF'},[13033]={30,'DEF'}, -- Ice Barrier ranks
  [2139]={30,'INT'}, -- Counterspell
  [1953]={15,'MOB'}, -- Blink
  -- PRIEST
  [17]={4,'DEF'},[592]={4,'DEF'},[600]={4,'DEF'},[3747]={4,'DEF'},[6065]={4,'DEF'},[6066]={4,'DEF'},[10898]={4,'DEF'},[10899]={4,'DEF'},[10900]={4,'DEF'},[10901]={4,'DEF'}, -- PW: Shield ranks
  [586]={30,'DEF'},[9578]={30,'DEF'},[9579]={30,'DEF'},[9592]={30,'DEF'},[10941]={30,'DEF'},[10942]={30,'DEF'}, -- Fade ranks
  [8122]={30,'CC'},[8124]={30,'CC'},[10888]={30,'CC'},[10890]={30,'CC'}, -- Psychic Scream ranks
  [15487]={45,'INT'}, -- Silence
  -- PALADIN
  [853]={60,'CC'},[5588]={60,'CC'},[5589]={60,'CC'},[10308]={60,'CC'}, -- Hammer of Justice ranks
  [879]={15,'OFF'},[5614]={15,'OFF'},[5615]={15,'OFF'},[10312]={15,'OFF'},[10313]={15,'OFF'},[10314]={15,'OFF'}, -- Exorcism ranks
  [24275]={6,'OFF'},[24274]={6,'OFF'},[24239]={6,'OFF'}, -- Hammer of Wrath ranks
  [498]={300,'DEF'}, -- Divine Protection
  [642]={300,'DEF'}, -- Divine Shield
  -- ROGUE
  [1766]={10,'INT'},[1767]={10,'INT'},[1768]={10,'INT'},[1769]={10,'INT'}, -- Kick ranks
  [408]={20,'CC'},[8643]={20,'CC'}, -- Kidney Shot ranks
  [2094]={300,'CC'}, -- Blind
  [5277]={300,'DEF'}, -- Evasion
  [2983]={300,'MOB'},[8696]={300,'MOB'},[11305]={300,'MOB'}, -- Sprint ranks
  [1856]={300,'DEF'},[1857]={300,'DEF'}, -- Vanish ranks
  -- DRUID
  [6795]={10,'CC'}, -- Growl
  [5211]={60,'CC'},[6798]={60,'CC'},[8983]={60,'CC'}, -- Bash ranks
  [16979]={15,'MOB'}, -- Feral Charge
  [1850]={300,'MOB'},[9821]={300,'MOB'}, -- Dash ranks
  [22812]={60,'DEF'}, -- Barkskin
  [16689]={60,'DEF'},[16810]={60,'DEF'},[16811]={60,'DEF'},[16812]={60,'DEF'},[16813]={60,'DEF'}, -- Nature's Grasp ranks
  -- HUNTER
  [1499]={30,'CC'},[14310]={30,'CC'},[14311]={30,'CC'}, -- Freezing Trap ranks
  [13809]={30,'CC'},[13813]={30,'CC'},[14316]={30,'CC'},[14317]={30,'CC'}, -- Frost Trap/Explosive Trap family
  [5384]={30,'DEF'}, -- Feign Death
  [781]={5,'MOB'}, -- Disengage (when available on client)
  [1543]={20,'DEF'}, -- Flare
  -- SHAMAN
  [8042]={6,'OFF'},[8044]={6,'OFF'},[8045]={6,'OFF'},[8046]={6,'OFF'},[10412]={6,'OFF'},[10413]={6,'OFF'},[10414]={6,'OFF'}, -- Earth Shock legacy ranks
  [408681]={6,'OFF'},[408683]={6,'OFF'},[408685]={6,'OFF'}, -- Forever Earth Shock variants
  [1220744]={6,'OFF'},[1220745]={6,'OFF'},[1220746]={6,'OFF'},[1220747]={6,'OFF'},[1220748]={6,'OFF'},[1220749]={6,'OFF'},[1220750]={6,'OFF'},[1220751]={6,'OFF'}, -- Forever melee/taunt Earth Shock ranks
  [8050]={6,'OFF'},[8052]={6,'OFF'},[8053]={6,'OFF'},[10447]={6,'OFF'},[10448]={6,'OFF'}, -- Flame Shock ranks
  [8056]={6,'CC'},[8058]={6,'CC'},[10472]={6,'CC'},[10473]={6,'CC'}, -- Frost Shock ranks
  [2484]={15,'CC'}, -- Earthbind Totem
  [8177]={15,'DEF'}, -- Grounding Totem
  [17364]={8,'OFF'}, -- Stormstrike (Forever 1.60.1)
  -- WARLOCK
  [6789]={120,'CC'},[17925]={120,'CC'},[17926]={120,'CC'},[27223]={120,'CC'}, -- Death Coil ranks/variant
  [5484]={40,'CC'},[17928]={40,'CC'}, -- Howl of Terror ranks
  [19505]={8,'INT'},[19731]={8,'INT'},[19734]={8,'INT'},[19736]={8,'INT'},[27276]={8,'INT'}, -- Spell Lock ranks
 }
 for id,v in pairs(shortCD) do spells[id]=v end
else
 -- MIDNIGHT: important cooldowns not covered by the original aura-first database.
 local extra = {
  -- DEATH KNIGHT
  [47528]={15,'INT'}, [49576]={25,'MOB'}, [108199]={120,'CC'}, [221562]={45,'CC'}, [51052]={120,'DEF'}, [48743]={120,'DEF'},
  -- DEMON HUNTER (Havoc/Vengeance/Devourer + PvP-important)
  [183752]={15,'INT'}, [179057]={60,'CC'}, [211881]={30,'CC'}, [217832]={45,'CC'},
  [198793]={20,'MOB'}, [195072]={10,'MOB'}, [370965]={90,'OFF'}, [204021]={60,'DEF'},
  [203720]={20,'DEF'}, [212084]={60,'OFF'}, [202137]={60,'CC'}, [207684]={60,'CC'},
  [202138]={60,'CC'}, [205604]={60,'DEF'}, [205630]={60,'DEF'}, [205629]={60,'DEF'},
  -- DRUID
  [106839]={15,'INT'}, [78675]={60,'INT'}, [132469]={30,'CC'}, [99]={30,'CC'}, [102359]={30,'CC'}, [5211]={60,'CC'},
  [102793]={60,'CC'}, [88423]={8,'DEF'}, [2782]={8,'DEF'}, [18562]={15,'DEF'},
  -- EVOKER
  [351338]={40,'INT'}, [358267]={30,'MOB'}, [358385]={90,'MOB'}, [368970]={60,'CC'}, [360806]={15,'CC'},
  [357210]={120,'DEF'}, [374251]={120,'DEF'},
  -- HUNTER
  [147362]={24,'INT'}, [187707]={15,'INT'}, [109248]={45,'CC'}, [187650]={30,'CC'}, [19577]={60,'CC'},
  [109304]={120,'DEF'}, [781]={20,'MOB'}, [1953]={15,'MOB'}, [272651]={45,'MOB'},
  -- MAGE (Arcane/Fire/Frost)
  [2139]={24,'INT'}, [1953]={15,'MOB'}, [122]={30,'CC'}, [31661]={45,'CC'}, [157981]={30,'CC'},
  [113724]={45,'CC'}, [120]={30,'CC'}, [157997]={25,'CC'}, [12051]={90,'OFF'}, [11958]={300,'DEF'},
  [414660]={120,'DEF'}, [414664]={120,'DEF'}, [414659]={120,'DEF'}, [157980]={25,'DEF'}, [108839]={60,'MOB'},
  -- MONK
  [116705]={15,'INT'}, [119381]={60,'CC'}, [115078]={15,'CC'}, [109132]={20,'MOB'}, [101545]={20,'MOB'},
  [115310]={180,'DEF'}, [322118]={180,'DEF'}, [325153]={60,'DEF'},
  -- PALADIN
  [96231]={15,'INT'}, [853]={60,'CC'}, [115750]={90,'CC'}, [190784]={45,'MOB'}, [633]={600,'DEF'},
  [204018]={180,'DEF'}, [231895]={120,'OFF'},
  -- PRIEST
  [15487]={45,'INT'}, [8122]={60,'CC'}, [64044]={45,'CC'}, [32375]={45,'OFF'}, [73325]={90,'MOB'},
  [586]={30,'DEF'}, [15286]={90,'DEF'},
  -- ROGUE
  [1766]={15,'INT'}, [408]={20,'CC'}, [2094]={120,'CC'}, [1776]={15,'CC'}, [36554]={30,'MOB'},
  [212283]={30,'DEF'}, [79140]={120,'OFF'}, [13877]={30,'OFF'},
  -- SHAMAN
  [57994]={12,'INT'}, [51514]={30,'CC'}, [51490]={45,'CC'}, [192058]={60,'CC'}, [58875]={60,'MOB'},
  [108280]={180,'DEF'}, [98008]={180,'DEF'}, [198103]={300,'OFF'},
  -- WARLOCK
  [19647]={24,'INT'}, [89766]={30,'CC'}, [6789]={45,'CC'}, [30283]={60,'CC'}, [5484]={40,'CC'},
  [48020]={30,'MOB'}, [48018]={30,'MOB'}, [108359]={120,'OFF'}, [205180]={120,'OFF'}, [1122]={180,'OFF'},
  -- WARRIOR
  [6552]={15,'INT'}, [5246]={90,'CC'}, [107570]={30,'CC'}, [46968]={40,'CC'}, [3411]={30,'DEF'},
  [6544]={45,'MOB'}, [236077]={45,'MOB'}, [1160]={45,'DEF'}, [97462]={180,'DEF'},
  -- SHORT / CORE COOLDOWNS: track them too; a cooldown does not need to be a major CD.
  [355]={8,'CC'}, [6343]={6,'OFF'}, [2565]={16,'DEF'}, [23922]={6,'OFF'}, [6572]={3,'OFF'}, [7384]={12,'OFF'},
  [122]={30,'CC'}, [120]={12,'CC'}, [31661]={45,'CC'}, [157981]={30,'CC'}, [2136]={12,'OFF'}, [108853]={12,'OFF'},
  [17]={7.5,'DEF'}, [586]={30,'DEF'}, [32379]={20,'OFF'}, [8092]={7.5,'OFF'},
  [6795]={8,'CC'}, [22842]={36,'DEF'}, [61336]={180,'DEF'}, [5211]={60,'CC'}, [132469]={30,'CC'},
  [62124]={8,'CC'}, [35395]={4.5,'OFF'}, [31935]={15,'INT'}, [184575]={12,'OFF'}, [24275]={7.5,'OFF'},
  [1766]={15,'INT'}, [408]={20,'CC'}, [1776]={15,'CC'}, [185311]={30,'DEF'}, [1966]={15,'DEF'},
  [57994]={12,'INT'}, [51490]={45,'CC'}, [51514]={30,'CC'}, [2484]={30,'CC'},
  [19647]={24,'INT'}, [6789]={45,'CC'}, [30283]={60,'CC'}, [5484]={40,'CC'}, [48020]={30,'MOB'},
  [147362]={24,'INT'}, [187707]={15,'INT'}, [109248]={45,'CC'}, [781]={20,'MOB'}, [5384]={30,'DEF'},
  [96231]={15,'INT'}, [853]={60,'CC'}, [190784]={45,'MOB'}, [498]={60,'DEF'},
  [116705]={15,'INT'}, [119381]={60,'CC'}, [115078]={15,'CC'}, [109132]={20,'MOB'},
  [47528]={15,'INT'}, [49576]={25,'MOB'}, [221562]={45,'CC'}, [48743]={120,'DEF'},
  [183752]={15,'INT'}, [179057]={60,'CC'}, [198793]={20,'MOB'}, [195072]={10,'MOB'},
  [351338]={40,'INT'}, [358267]={30,'MOB'}, [368970]={60,'CC'}, [360806]={15,'CC'},
 }
 for id,v in pairs(extra) do spells[id]=v end
end


-- GODMODE COMPLETE-CD SUPPLEMENT (2026-10-07)
-- Static coverage is intentionally broad: every known active class ability with a genuine
-- cooldown is eligible, including short 3-15s abilities.  GCD-only/passive/auto attacks stay out.
-- The locked nameplate governor is NOT modified by this database.
local completeCD = {}
if iface == 16001 then
 completeCD = {
  -- WARRIOR: Arms/Fury/Protection + Forever talents/ranks
  [355]={10,'CC'},[100]={15,'MOB'},[6178]={15,'MOB'},[11578]={15,'MOB'},[20252]={30,'MOB'},[20616]={30,'MOB'},[20617]={30,'MOB'},
  [6343]={6,'OFF'},[8198]={6,'OFF'},[8204]={6,'OFF'},[8205]={6,'OFF'},[11580]={6,'OFF'},[11581]={6,'OFF'},[2565]={5,'DEF'},
  [72]={12,'INT'},[1671]={12,'INT'},[1672]={12,'INT'},[676]={60,'CC'},[1161]={600,'CC'},[5246]={180,'CC'},[7384]={5,'OFF'},[7887]={5,'OFF'},[11584]={5,'OFF'},[11585]={5,'OFF'},
  [1680]={10,'OFF'},[12294]={6,'OFF'},[21551]={6,'OFF'},[21552]={6,'OFF'},[21553]={6,'OFF'},[23881]={6,'OFF'},[23892]={6,'OFF'},[23893]={6,'OFF'},[23894]={6,'OFF'},
  [2687]={60,'OFF'},[18499]={30,'DEF'},[12328]={30,'OFF'},[12292]={180,'OFF'},[12975]={600,'DEF'},[871]={1800,'DEF'},[1719]={1800,'OFF'},[20230]={1800,'DEF'},
  -- PALADIN
  [853]={60,'CC'},[5588]={60,'CC'},[5589]={60,'CC'},[10308]={60,'CC'},[879]={15,'OFF'},[5614]={15,'OFF'},[5615]={15,'OFF'},[10312]={15,'OFF'},[10313]={15,'OFF'},[10314]={15,'OFF'},
  [24275]={6,'OFF'},[24274]={6,'OFF'},[24239]={6,'OFF'},[498]={300,'DEF'},[642]={300,'DEF'},[1020]={300,'DEF'},[1022]={300,'DEF'},[5599]={300,'DEF'},[10278]={300,'DEF'},
  [633]={3600,'DEF'},[2800]={3600,'DEF'},[10310]={3600,'DEF'},[20216]={120,'OFF'},[20066]={60,'CC'},
  -- HUNTER
  [781]={5,'MOB'},[5384]={30,'DEF'},[1543]={20,'DEF'},[1499]={30,'CC'},[14310]={30,'CC'},[14311]={30,'CC'},[13809]={30,'CC'},[13813]={30,'CC'},[14316]={30,'CC'},[14317]={30,'CC'},
  [3045]={300,'OFF'},[19574]={120,'OFF'},[19263]={300,'DEF'},[19386]={60,'CC'},[19577]={60,'CC'},[23989]={300,'OFF'},[1510]={60,'OFF'},[5116]={6,'CC'},
  -- ROGUE
  [1766]={10,'INT'},[1767]={10,'INT'},[1768]={10,'INT'},[1769]={10,'INT'},[408]={20,'CC'},[8643]={20,'CC'},[1776]={10,'CC'},[1777]={10,'CC'},[8629]={10,'CC'},[11285]={10,'CC'},[11286]={10,'CC'},
  [2094]={300,'CC'},[5277]={300,'DEF'},[2983]={300,'MOB'},[8696]={300,'MOB'},[11305]={300,'MOB'},[1856]={300,'DEF'},[1857]={300,'DEF'},[14185]={600,'DEF'},[13750]={300,'OFF'},[13877]={120,'OFF'},[14177]={180,'OFF'},[14183]={180,'OFF'},
  -- PRIEST
  [17]={4,'DEF'},[592]={4,'DEF'},[600]={4,'DEF'},[3747]={4,'DEF'},[6065]={4,'DEF'},[6066]={4,'DEF'},[10898]={4,'DEF'},[10899]={4,'DEF'},[10900]={4,'DEF'},[10901]={4,'DEF'},
  [586]={30,'DEF'},[9578]={30,'DEF'},[9579]={30,'DEF'},[9592]={30,'DEF'},[10941]={30,'DEF'},[10942]={30,'DEF'},[8122]={30,'CC'},[8124]={30,'CC'},[10888]={30,'CC'},[10890]={30,'CC'},
  [15487]={45,'INT'},[10060]={180,'OFF'},[14751]={180,'OFF'},[19236]={600,'DEF'},[6346]={30,'DEF'},[15286]={180,'DEF'},
  -- SHAMAN
  [8042]={6,'OFF'},[8044]={6,'OFF'},[8045]={6,'OFF'},[8046]={6,'OFF'},[10412]={6,'OFF'},[10413]={6,'OFF'},[10414]={6,'OFF'},[8050]={6,'OFF'},[8052]={6,'OFF'},[8053]={6,'OFF'},[10447]={6,'OFF'},[10448]={6,'OFF'},
  [8056]={6,'CC'},[8058]={6,'CC'},[10472]={6,'CC'},[10473]={6,'CC'},[2484]={15,'CC'},[8177]={15,'DEF'},[16166]={180,'OFF'},[16188]={180,'DEF'},[16190]={300,'DEF'},[17364]={20,'OFF'},
  -- MAGE
  [122]={25,'CC'},[865]={25,'CC'},[6131]={25,'CC'},[10230]={25,'CC'},[120]={10,'CC'},[8492]={10,'CC'},[10159]={10,'CC'},[10160]={10,'CC'},[10161]={10,'CC'},
  [2136]={8,'OFF'},[2137]={8,'OFF'},[2138]={8,'OFF'},[8412]={8,'OFF'},[8413]={8,'OFF'},[10197]={8,'OFF'},[10199]={8,'OFF'},[2139]={30,'INT'},[1953]={15,'MOB'},
  [11113]={45,'CC'},[13018]={45,'CC'},[13019]={45,'CC'},[13020]={45,'CC'},[13021]={45,'CC'},[11426]={30,'DEF'},[13031]={30,'DEF'},[13032]={30,'DEF'},[13033]={30,'DEF'},
  [45438]={300,'DEF'},[12042]={180,'OFF'},[12043]={180,'OFF'},[11958]={600,'DEF'},[12051]={480,'OFF'},[12472]={180,'OFF'},[11129]={180,'OFF'},[66]={300,'DEF'},
  -- WARLOCK (player + pet active CDs)
  [6789]={120,'CC'},[17925]={120,'CC'},[17926]={120,'CC'},[27223]={120,'CC'},[5484]={40,'CC'},[17928]={40,'CC'},[19505]={8,'INT'},[19731]={8,'INT'},[19734]={8,'INT'},[19736]={8,'INT'},[27276]={8,'INT'},
  [17962]={10,'OFF'},[18288]={180,'OFF'},[18708]={900,'DEF'},[6229]={30,'DEF'},[11739]={30,'DEF'},[11740]={30,'DEF'},[28610]={30,'DEF'},[20707]={1800,'DEF'},
  -- DRUID
  [6795]={10,'CC'},[5211]={60,'CC'},[6798]={60,'CC'},[8983]={60,'CC'},[16979]={15,'MOB'},[1850]={300,'MOB'},[9821]={300,'MOB'},[22812]={60,'DEF'},
  [16689]={60,'DEF'},[16810]={60,'DEF'},[16811]={60,'DEF'},[16812]={60,'DEF'},[16813]={60,'DEF'},[17116]={180,'OFF'},[29166]={360,'OFF'},[740]={300,'DEF'},[8998]={10,'DEF'},[9000]={10,'DEF'},[9892]={10,'DEF'},
  -- Forever racials / universal
  [20572]={120,'OFF'},[26297]={180,'OFF'},[7744]={120,'DEF'},[20594]={180,'DEF'},[20600]={180,'DEF'},[20589]={105,'MOB'},[20549]={120,'CC'},[1259416]={120,'MOB'},[1259705]={120,'OFF'},
 }
else
 completeCD = {
  -- DEATH KNIGHT
  [47528]={15,'INT'},[49576]={25,'MOB'},[48707]={60,'DEF'},[48792]={120,'DEF'},[48743]={120,'DEF'},[49039]={120,'DEF'},[51052]={120,'DEF'},[55233]={90,'DEF'},[49028]={120,'DEF'},[47568]={120,'OFF'},[51271]={60,'OFF'},[108199]={120,'CC'},[221562]={45,'CC'},[43265]={30,'OFF'},[48721]={40,'OFF'},[49020]={8,'OFF'},[85948]={6,'OFF'},[196770]={20,'OFF'},
  -- DEMON HUNTER
  [183752]={15,'INT'},[179057]={60,'CC'},[211881]={30,'CC'},[217832]={45,'CC'},[198793]={20,'MOB'},[195072]={10,'MOB'},[198589]={60,'DEF'},[196555]={180,'DEF'},[196718]={180,'DEF'},[191427]={180,'OFF'},[187827]={180,'OFF'},[188501]={30,'MOB'},[203720]={20,'DEF'},[204021]={60,'DEF'},[202137]={60,'CC'},[207684]={60,'CC'},[202138]={60,'CC'},[212084]={60,'OFF'},[370965]={90,'OFF'},[205604]={60,'DEF'},[205630]={60,'DEF'},[205629]={60,'DEF'},
  -- DRUID
  [106839]={15,'INT'},[78675]={60,'INT'},[6795]={8,'CC'},[5211]={60,'CC'},[99]={30,'CC'},[132469]={30,'CC'},[102359]={30,'CC'},[102793]={60,'CC'},[1850]={120,'MOB'},[252216]={45,'MOB'},[22812]={60,'DEF'},[61336]={180,'DEF'},[22842]={36,'DEF'},[18562]={15,'DEF'},[2782]={8,'DEF'},[88423]={8,'DEF'},[106898]={120,'MOB'},[194223]={120,'OFF'},[106951]={180,'OFF'},[29166]={180,'OFF'},[102342]={90,'DEF'},[102543]={180,'OFF'},[102558]={180,'OFF'},[102560]={180,'OFF'},[33891]={180,'OFF'},
  -- EVOKER
  [351338]={40,'INT'},[358267]={30,'MOB'},[358385]={90,'MOB'},[368970]={60,'CC'},[360806]={15,'CC'},[363916]={90,'DEF'},[374348]={90,'DEF'},[357210]={120,'DEF'},[374251]={120,'DEF'},[374227]={120,'DEF'},[357170]={60,'DEF'},[375087]={120,'OFF'},[370960]={180,'DEF'},[378464]={120,'MOB'},[370553]={120,'OFF'},[390386]={300,'OFF'},[357208]={30,'MOB'},[355913]={8,'OFF'},[357211]={24,'OFF'},
  -- HUNTER
  [147362]={24,'INT'},[187707]={15,'INT'},[109248]={45,'CC'},[187650]={30,'CC'},[19577]={60,'CC'},[781]={20,'MOB'},[5384]={30,'DEF'},[109304]={120,'DEF'},[186265]={180,'DEF'},[186257]={180,'MOB'},[53480]={60,'DEF'},[264735]={180,'DEF'},[392956]={120,'DEF'},[19574]={90,'OFF'},[288613]={120,'OFF'},[360966]={120,'OFF'},[359844]={120,'OFF'},[272651]={45,'MOB'},[1543]={20,'DEF'},[186387]={30,'CC'},
  -- MAGE
  [2139]={24,'INT'},[1953]={15,'MOB'},[122]={30,'CC'},[120]={12,'CC'},[31661]={45,'CC'},[157981]={30,'CC'},[113724]={45,'CC'},[157997]={25,'CC'},[66]={300,'DEF'},[110960]={120,'DEF'},[45438]={240,'DEF'},[414658]={240,'DEF'},[55342]={120,'DEF'},[342245]={60,'DEF'},[342246]={60,'DEF'},[11426]={25,'DEF'},[235313]={25,'DEF'},[235450]={25,'DEF'},[108839]={60,'MOB'},[12051]={90,'OFF'},[12472]={120,'OFF'},[190319]={120,'OFF'},[365350]={90,'OFF'},[11958]={300,'DEF'},[2136]={12,'OFF'},[108853]={12,'OFF'},[153595]={30,'OFF'},[157980]={25,'DEF'},
  -- MONK
  [116705]={15,'INT'},[119381]={60,'CC'},[115078]={15,'CC'},[109132]={20,'MOB'},[101545]={20,'MOB'},[116841]={30,'MOB'},[115203]={360,'DEF'},[243435]={360,'DEF'},[115176]={300,'DEF'},[116849]={120,'DEF'},[122278]={120,'DEF'},[122783]={90,'DEF'},[322507]={60,'DEF'},[115310]={180,'DEF'},[322118]={180,'DEF'},[325153]={60,'DEF'},[137639]={90,'OFF'},[152173]={90,'OFF'},[123904]={120,'OFF'},[132578]={180,'DEF'},[198664]={180,'OFF'},[325197]={180,'OFF'},[113656]={24,'OFF'},[100780]={4,'OFF'},
  -- PALADIN
  [96231]={15,'INT'},[853]={60,'CC'},[115750]={90,'CC'},[62124]={8,'CC'},[190784]={45,'MOB'},[498]={60,'DEF'},[642]={300,'DEF'},[1022]={300,'DEF'},[1044]={25,'MOB'},[6940]={120,'DEF'},[633]={600,'DEF'},[31821]={180,'DEF'},[31850]={120,'DEF'},[31884]={120,'OFF'},[86659]={300,'DEF'},[105809]={120,'OFF'},[184662]={120,'DEF'},[205191]={60,'DEF'},[216331]={120,'OFF'},[327193]={120,'DEF'},[204018]={180,'DEF'},[231895]={120,'OFF'},[35395]={4.5,'OFF'},[31935]={15,'INT'},[184575]={12,'OFF'},[24275]={7.5,'OFF'},
  -- PRIEST
  [15487]={45,'INT'},[8122]={60,'CC'},[64044]={45,'CC'},[73325]={90,'MOB'},[586]={30,'DEF'},[17]={7.5,'DEF'},[19236]={90,'DEF'},[33206]={180,'DEF'},[47585]={120,'DEF'},[47788]={180,'DEF'},[213602]={30,'DEF'},[15286]={90,'DEF'},[10060]={120,'OFF'},[47536]={90,'OFF'},[194249]={120,'OFF'},[200183]={120,'OFF'},[391109]={60,'OFF'},[421453]={240,'OFF'},[32375]={45,'OFF'},[32379]={20,'OFF'},[8092]={7.5,'OFF'},[34433]={180,'OFF'},
  -- ROGUE
  [1766]={15,'INT'},[408]={20,'CC'},[2094]={120,'CC'},[1776]={15,'CC'},[36554]={30,'MOB'},[2983]={120,'MOB'},[1856]={120,'DEF'},[1966]={15,'DEF'},[5277]={120,'DEF'},[31224]={120,'DEF'},[212283]={30,'DEF'},[185311]={30,'DEF'},[13750]={180,'OFF'},[121471]={120,'OFF'},[185422]={60,'OFF'},[343142]={90,'OFF'},[360194]={120,'OFF'},[381623]={60,'OFF'},[51690]={120,'OFF'},[114018]={360,'DEF'},[79140]={120,'OFF'},[13877]={30,'OFF'},[195457]={45,'MOB'},
  -- SHAMAN
  [57994]={12,'INT'},[51514]={30,'CC'},[51490]={45,'CC'},[192058]={60,'CC'},[2484]={30,'CC'},[58875]={60,'MOB'},[108271]={90,'DEF'},[30823]={60,'DEF'},[108280]={180,'DEF'},[98008]={180,'DEF'},[108281]={120,'DEF'},[79206]={120,'MOB'},[114050]={180,'OFF'},[114051]={180,'OFF'},[114052]={180,'OFF'},[384352]={60,'OFF'},[198103]={300,'OFF'},[204366]={45,'DEF'},[108285]={10,'OFF'},[51533]={120,'OFF'},
  -- WARLOCK
  [19647]={24,'INT'},[89766]={30,'CC'},[6789]={45,'CC'},[30283]={60,'CC'},[5484]={40,'CC'},[48020]={30,'MOB'},[48018]={30,'MOB'},[104773]={180,'DEF'},[108416]={60,'DEF'},[212295]={45,'DEF'},[386997]={30,'OFF'},[108359]={120,'OFF'},[205180]={120,'OFF'},[1122]={180,'OFF'},[113858]={120,'OFF'},[113860]={120,'OFF'},[111400]={1,'MOB'},[333889]={60,'MOB'},
  -- WARRIOR
  [6552]={15,'INT'},[355]={8,'CC'},[5246]={90,'CC'},[107570]={30,'CC'},[46968]={40,'CC'},[3411]={30,'DEF'},[6544]={45,'MOB'},[236077]={45,'MOB'},[100]={20,'MOB'},[6343]={6,'OFF'},[2565]={16,'DEF'},[23922]={6,'OFF'},[6572]={3,'OFF'},[7384]={12,'OFF'},[1160]={45,'DEF'},[871]={240,'DEF'},[12975]={180,'DEF'},[97462]={180,'DEF'},[118038]={120,'DEF'},[184364]={120,'DEF'},[18499]={60,'DEF'},[23920]={25,'DEF'},[1719]={90,'OFF'},[107574]={90,'OFF'},[227847]={90,'OFF'},[46924]={90,'OFF'},[198817]={25,'OFF'},[12292]={180,'OFF'},[12328]={30,'OFF'},[20230]={1800,'DEF'},
  -- common racials / PvP-visible racials
  [20572]={120,'OFF'},[26297]={180,'OFF'},[58984]={120,'DEF'},[59752]={180,'DEF'},[7744]={120,'DEF'},[20594]={120,'DEF'},[68992]={120,'MOB'},[20589]={90,'MOB'},[107079]={120,'CC'},[255654]={120,'OFF'},[287712]={150,'OFF'},[312411]={90,'DEF'},
 }
end
for id,v in pairs(completeCD) do spells[id]=v end
-- Forever confirmed values / additional active rank families. Keep these AFTER supplements.
if iface == 16001 then
 spells[17364]={8,'OFF'} -- Stormstrike: Forever spell 17364, 8 sec
 -- Verified Forever 1.60.1 rank/variant IDs. Keep AFTER supplements so generic tables cannot overwrite them.
 spells[5116]={12,'CC'} -- Concussive Shot, Forever 12 sec
 local foreverRanks={
  -- Shaman Forever shock variants (6 sec shared Shock cooldown)
  [408681]={6,'OFF'},[408683]={6,'OFF'},[408685]={6,'OFF'},[408687]={6,'OFF'},[408688]={6,'OFF'},[408689]={6,'OFF'},[408690]={6,'OFF'},
  [1220744]={6,'OFF'},[1220745]={6,'OFF'},[1220746]={6,'OFF'},[1220747]={6,'OFF'},[1220748]={6,'OFF'},[1220749]={6,'OFF'},[1220750]={6,'OFF'},[1220751]={6,'OFF'},
  [1213482]={6,'OFF'},[1222942]={6,'OFF'}, -- Forever Flame Shock variants seen in client DB
  [1248001]={6,'CC'}, -- Forever Frost Shock variant seen in client DB
  -- Hunter verified Forever cooldowns
  [5116]={12,'CC'},[19503]={30,'CC'}, -- Concussive Shot / Scatter Shot
  -- Hunter active cooldown/rank families
  [19434]={6,'OFF'},[20900]={6,'OFF'},[20901]={6,'OFF'},[20902]={6,'OFF'},[20903]={6,'OFF'},[20904]={6,'OFF'}, -- Aimed Shot
  [2973]={6,'OFF'},[14260]={6,'OFF'},[14261]={6,'OFF'},[14262]={6,'OFF'},[14263]={6,'OFF'},[14264]={6,'OFF'},[14265]={6,'OFF'}, -- Raptor Strike
  [1495]={5,'OFF'},[14269]={5,'OFF'},[14270]={5,'OFF'},[14271]={5,'OFF'}, -- Mongoose Bite
  [1510]={60,'OFF'},[14294]={60,'OFF'},[14295]={60,'OFF'}, -- Volley
  -- Warlock active cooldown/rank families
  [17877]={15,'OFF'},[18867]={15,'OFF'},[18868]={15,'OFF'},[18869]={15,'OFF'},[18870]={15,'OFF'},[18871]={15,'OFF'}, -- Shadowburn
  [6229]={30,'DEF'},[11739]={30,'DEF'},[11740]={30,'DEF'}, -- Shadow Ward
 }
 for id,v in pairs(foreverRanks) do spells[id]=v end
end

-- Safe database backstop. If Blizzard reports a successful cast whose ID is not yet in the
-- static table, ask the client for its BASE cooldown. This is event-only (only on an actual cast),
-- never a scan. It lets new/hotfixed/rank-specific cooldown spells work without touching the
-- locked nameplate lifecycle. Secret/inaccessible values are rejected.
local function accessible(v)
 if type(issecretvalue)=='function' then local ok,r=pcall(issecretvalue,v); if ok and r then return false end end
 if type(canaccessvalue)=='function' then local ok,r=pcall(canaccessvalue,v); if ok and r==false then return false end end
 return true
end
local function field(t,k)
 if type(t)~='table' then return nil end
 local ok,v=pcall(function() return t[k] end)
 if not ok or not accessible(v) then return nil end
 return v
end
local function resolveObservedSpell(id)
 local spec=spells[id]; if spec then return spec end
 local ms
 if type(GetSpellBaseCooldown)=='function' then
  local ok,v=pcall(GetSpellBaseCooldown,id)
  if ok and type(v)=='number' and accessible(v) then ms=v end
 end
 if (not ms or ms<=1500) and C_Spell and type(C_Spell.GetSpellCooldown)=='function' then
  local ok,info=pcall(C_Spell.GetSpellCooldown,id)
  if ok and type(info)=='table' then
   local d=field(info,'duration')
   if type(d)=='number' and accessible(d) and d>1.5 then ms=d*1000 end
  end
 end
 if type(ms)=='number' and ms>1500 then
  local sec=ms/1000
  -- Unknown genuine cooldown: track as offensive/utility by default. Known IDs above retain
  -- their precise INT/DEF/CC/MOB category.
  spec={sec,'OFF'}; spells[id]=spec
  return spec
 end
end

local function db()
 local d=_G[KEY]; if type(d)~='table' then d={}; _G[KEY]=d end
 for k,v in pairs(defaults) do if d[k]==nil then d[k]=v end end
 return d
end
local function safeBool(fn,...)
 if type(fn)~='function' then return nil end
 local ok,v=pcall(fn,...); if not ok or v==nil or not accessible(v) then return nil end
 return v and true or false
end
local function safeNumber(v) if type(v)=='number' and accessible(v) then return v end end
local function safeGUID(unit)
 local ok,v=pcall(UnitGUID,unit); if ok and type(v)=='string' and accessible(v) then return v end
end
-- Opposing-faction players on PvE realms may not be attackable until PvP flagged.
-- Determine hostility independently of attackability; never compare secret values.
local function opposingPlayerFaction(unit)
  if safeBool(UnitExists,unit)~=true or safeBool(UnitIsPlayer,unit)~=true then return false end
  if safeBool(UnitIsUnit,unit,'player')==true then return false end
  if type(UnitFactionGroup)~='function' then return false end
  local okA,a=pcall(UnitFactionGroup,'player')
  local okB,b=pcall(UnitFactionGroup,unit)
  if not okA or not okB or type(a)~='string' or type(b)~='string' then return false end
  if not accessible(a) or not accessible(b) then return false end
  if (a~='Alliance' and a~='Horde') or (b~='Alliance' and b~='Horde') then return false end
  return a~=b
end
-- Track attackable players as enemies. Non-attackable players use the friendly
-- tracking path regardless of faction/PvP flag, so their casts are not dropped.
-- Unknown attackability is never treated as a confirmed enemy.
local function trackerPlayerRelation(unit)
  if safeBool(UnitExists,unit)~=true or safeBool(UnitIsPlayer,unit)~=true then return end
  if safeBool(UnitIsUnit,unit,'player')==true then return end
  local attackable=safeBool(UnitCanAttack,'player',unit)
  if attackable==true then return 'ENEMY' end
  if attackable==false then return 'FRIEND' end
  if safeBool(UnitIsFriend,'player',unit)==true then return 'FRIEND' end
end
local function relation(unit)
  if type(unit)~='string' or not unit:match('^nameplate%d+$') then return end
  return trackerPlayerRelation(unit)
end
local function allowed(cat,rel)
 local d=db(); if not d.enabled then return false end
 if rel=='ENEMY' and not d.enemy then return false end
 if rel=='FRIEND' and not d.friendly then return false end
 return (cat=='INT' and d.interrupts) or (cat=='DEF' and d.defensives) or (cat=='OFF' and d.offensives) or (cat=='CC' and d.cc) or (cat=='MOB' and d.mobility)
end
local function getPlate(unit)
 if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
 local ok,p=pcall(C_NamePlate.GetNamePlateForUnit,unit); if not ok or not p then return end
 if p.IsForbidden then local okf,f=pcall(p.IsForbidden,p); if okf and f then return end end
 return p
end
local function spellName(id)
 if C_Spell and C_Spell.GetSpellName then local ok,v=pcall(C_Spell.GetSpellName,id); if ok and type(v)=='string' and accessible(v) then return v end end
 if GetSpellInfo then local v=GetSpellInfo(id); if type(v)=='string' and accessible(v) then return v end end
 return 'Cooldown'
end
local function spellTexture(id)
 if C_Spell and C_Spell.GetSpellTexture then local ok,v=pcall(C_Spell.GetSpellTexture,id); if ok and accessible(v) and v then return v end end
 if GetSpellTexture then local v=GetSpellTexture(id); if accessible(v) and v then return v end end
 return 134400
end

-- CURRENT TARGET OBSERVER (Forever/Midnight-safe design):
-- This module never scans the world.  It only inspects the player's current target when
-- Blizzard tells us that target's auras changed.  Restricted/secret aura values are ignored.
local function targetRelation()
  return trackerPlayerRelation('target')
end
local function trackerRelation(unit)
  return trackerPlayerRelation(unit)
end
local function trackerDisplayUnit()
 local d=db()
 -- In group instances transient mouseovers (party, pets, overlapping mobs) must
 -- not replace a valid selected target on the target-frame cooldown display.
 -- Keep the original mouseover-first behavior in the open world and use
 -- mouseover as a fallback in instances when no valid target exists.
 local inInstance, instanceType = false, nil
 if type(IsInInstance)=='function' then
  local ok, inside, kind = pcall(IsInInstance)
  if ok then inInstance, instanceType = inside, kind end
 end
 if inInstance and (instanceType=='party' or instanceType=='raid') then
  if targetRelation() and safeGUID('target') then return 'target' end
 end
 if d.targetMouseover~=false and trackerRelation('mouseover') and safeGUID('mouseover') then return 'mouseover' end
 if targetRelation() and safeGUID('target') then return 'target' end
end

-- Lifecycle maps. No 40-nameplate scans, no OnUpdate, no ticker.
-- plateState is bounded by Blizzard's recycled nameplate frame pool.
local plateState = {}       -- [plate] = { frame=..., items={} }
local unitToPlate = {}      -- [nameplateN] = plate while visible
local guidToUnit = {}       -- readable GUID -> visible nameplate token
local active = {}           -- readable GUID -> spellID -> cooldown record
-- Per-caster observed cooldown intervals. A shortened interval is NOT proof of a
-- talent (resets and other modifiers exist), so only learn after TWO consistent
-- successful-cast intervals. Nothing is saved or inferred from the player's talents.
-- This is event-driven and never runs during nameplate/camera updates.
local observedCastIntervals = {} -- GUID -> spellID -> {last, candidate, count, learned}
local function observedCastDuration(guid,id,base,now)
 if type(guid)~='string' or not accessible(guid) then return base end
 if type(id)~='number' or type(base)~='number' or base<=3 then return base end
 local bucket=observedCastIntervals[guid]
 if not bucket then bucket={}; observedCastIntervals[guid]=bucket end
 local rec=bucket[id]
 if not rec then rec={last=now}; bucket[id]=rec; return base end
 local interval=now-rec.last
 -- Suppress duplicate reports of the same cast; don't let them teach a reduction.
 if interval<=2.5 then return rec.learned or base end
 rec.last=now
 if interval>=base-0.5 then
  rec.candidate=nil; rec.count=0
 elseif interval>=3 and interval>=base*0.45 then
  -- Ignore wildly shortened intervals (likely cooldown resets), and require
  -- two closely matching observations before changing subsequent timers.
  if rec.candidate and math.abs(rec.candidate-interval)<=1.5 then
   rec.count=(rec.count or 0)+1
   if rec.count>=2 then rec.learned=math.min(base,math.max(interval,rec.candidate)) end
  else
   rec.candidate=interval; rec.count=1
  end
 end
 return rec.learned or base
end
local targetDisplay          -- dedicated current-target tracker; created lazily
local scheduleExpiry, announce -- forward declarations for target observer


-- Forever/Midnight observable-aura sound engine.
-- Blizzard 12.1 can hide aura/cast values from Lua, but C_UnitAuras.AddAuraSound can still
-- match a known spell inside the engine.  This path is completely dormant while Sounds is OFF.
local auraSoundHandles = {} -- [unitToken] = { engine handles }
local AURA_SOUND_FILE = 'Interface\\AddOns\\OmniCC_GODMODE\\sounds\\player_alert.ogg'
local AURA_SOUND_CHANNEL = 'Master'
local observableAuraSpells = {}
for spellID,info in pairs(spells) do
 local cat=info[2]
 -- Interrupts are cast events, not auras on the caster.  The remaining categories contain
 -- self-buffs and/or player auras that the engine can observe without exposing secret values.
 if cat~='INT' then observableAuraSpells[spellID]=cat end
end
local function removeAuraSounds(unit)
 local ids=auraSoundHandles[unit]; if not ids then return end
 if C_UnitAuras and C_UnitAuras.RemoveAuraSound then
  for i=1,#ids do pcall(C_UnitAuras.RemoveAuraSound,ids[i]) end
 end
 auraSoundHandles[unit]=nil
end
local function removeAllAuraSounds()
 for unit in pairs(auraSoundHandles) do removeAuraSounds(unit) end
end
local function registerAuraSounds(unit)
 local d=db()
 if not d.enabled or not d.sounds or not C_UnitAuras or not C_UnitAuras.AddAuraSound then return end
 local rel=relation(unit); if not rel then return end
 if (rel=='ENEMY' and not d.enemy) or (rel=='FRIEND' and not d.friendly) then return end
 removeAuraSounds(unit)
 local ids={}
 for spellID,cat in pairs(observableAuraSpells) do
  if allowed(cat,rel) then
   local info={unitToken=unit,spellID=spellID,soundFileName=AURA_SOUND_FILE,outputChannel=AURA_SOUND_CHANNEL}
   local ok,handle=pcall(C_UnitAuras.AddAuraSound,Enum.UnitAuraSoundTrigger.Added,info)
   if ok and type(handle)=='number' then ids[#ids+1]=handle end
  end
 end
 if #ids>0 then auraSoundHandles[unit]=ids end
end
local function registerVisibleAuraSoundsOnce()
 if not db().sounds or not C_NamePlate or not C_NamePlate.GetNamePlates then return end
 local ok,plates=pcall(C_NamePlate.GetNamePlates); if not ok or type(plates)~='table' then return end
 for i=1,#plates do
  local plate=plates[i]
  local unit=plate and (plate.namePlateUnitToken or plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit))
  if type(unit)=='string' then registerAuraSounds(unit) end
 end
end

local function stateFor(plate)
 local s=plateState[plate]; if s then return s end
 local f=CreateFrame('Frame',nil,UIParent); f:SetFrameStrata('HIGH'); f:EnableMouse(false); f.items={}; f:Hide()
 s={frame=f,items=f.items,isTarget=false}; plateState[plate]=s
 return s
end
-- Tracker countdowns are native Cooldown FontStrings. Style only existing icons;
-- never create additional nameplate auras or scan nameplates for theme changes.
local function styleTrackerCountdown(b)
 -- Tracker icons use the Nameplates theme unless Auto Fit is enabled.
 -- They are separate GODMODE cooldowns, not TPerl aura buttons.
 local profile=Addon.db and Addon.db.profile
 if not profile or not b or not b.cd or not b.cd.GetCountdownFontString then return end
 local themeID=profile.godmodeAutoFitEnabled and 'godmode_autofit' or 'nameplates'
 local t=profile.themes and profile.themes[themeID]
 if not t then return end
 local ok,fs=pcall(b.cd.GetCountdownFontString,b.cd)
 if not ok or not fs then return end
 local size=tonumber(b:GetWidth()) or 30
 local slider=tonumber(t.fontSize) or 15
 local preferred
 if themeID=='godmode_autofit' then
  preferred=5+10*math.max(0,math.min(99,slider))/99
 else
  preferred=slider
 end
 local actual=math.max(1,math.min(preferred,size*0.46))
 local font=STANDARD_TEXT_FONT
 if LibStub then
  local okMedia,media=pcall(LibStub,'LibSharedMedia-3.0',true)
  if okMedia and media and media.Fetch then
   local okFont,path=pcall(media.Fetch,media,'font',t.font)
   if okFont and type(path)=='string' then font=path end
  end
 end
 pcall(fs.SetFont,fs,font,actual,t.fontFlags or 'OUTLINE')
 if fs.SetShadowOffset then
  local shadow=t.shadow or t.textShadow
  pcall(fs.SetShadowOffset,fs,shadow and 1 or 0,shadow and -1 or 0)
 end
 -- No nameplate scans, polling or custom OnUpdate: use native countdown text.
 local remaining=b._trackerExpire and math.max(0,b._trackerExpire-GetTime()) or 0
 local hex=t.defaultTextColor
 if type(t.textColors)=='table' then
  local bestThreshold
  for _,entry in ipairs(t.textColors) do
   local threshold=tonumber(entry.threshold)
   if threshold and remaining<=threshold and (not bestThreshold or threshold<bestThreshold) then
    hex=entry.color; bestThreshold=threshold
   end
  end
 end
 if type(hex)=='string' and fs.SetTextColor then
  hex=hex:gsub('#','')
  if #hex>=6 then
   local r,g,bl=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
   local alpha=#hex>=8 and tonumber(hex:sub(7,8),16) or 255
   if r and g and bl then pcall(fs.SetTextColor,fs,r/255,g/255,bl/255,(alpha or 255)/255) end
  end
 end
end
local function itemFor(s,i)
 local b=s.items[i]; if b then return b end
 b=CreateFrame('Frame',nil,s.frame); b:Hide()
 b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetPoint('LEFT',b,'LEFT',0,0)
 b.cd=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate'); b.cd:SetDrawEdge(true); b.cd:SetDrawBling(false); b.cd:SetHideCountdownNumbers(false)
 b.name=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); b.name:SetJustifyH('LEFT'); b.name:SetWordWrap(false)
 -- Both target-frame and nameplate cooldown icons expose the same spell tooltip.
 do
  b:EnableMouse(true)
  b:SetScript('OnEnter',function(self)
   if not self._spellID then return end
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); local ok=false; if GameTooltip.SetSpellByID then ok=pcall(GameTooltip.SetSpellByID,GameTooltip,self._spellID) end; if not ok then GameTooltip:SetText(spellName(self._spellID)) end; GameTooltip:Show()
  end)
  b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 end
 s.items[i]=b; return b
end
local function hideState(s)
 if not s then return end
 for _,b in ipairs(s.items) do b:Hide() end
 s.frame:Hide()
end
local function cleanupBucket(guid)
 local bucket=active[guid]; if not bucket then return end
 local now=GetTime()
 for id,e in pairs(bucket) do if e.expire<=now then bucket[id]=nil end end
 if not next(bucket) then active[guid]=nil end
end
local function refreshUnit(unit)
 local plate=unitToPlate[unit] or getPlate(unit); if not plate then return end
 -- HOT PATH: never allocate a display frame merely because a nameplate appeared.
 -- Resolve relation/GUID first, and if this player has no tracked cooldowns there is nothing to render.
 local rel=relation(unit); local guid=safeGUID(unit)
 -- Independent visual gate: retain cast knowledge for the Target Frame.
 if db().nameplateEnabled==false then
  local old=plateState[plate]; if old then hideState(old) end
  return
 end
 if not rel or not guid then
  local old=plateState[plate]; if old then hideState(old) end
  return
 end
 guidToUnit[guid]=unit; cleanupBucket(guid)
 local bucket=active[guid]
 if not bucket then
  local old=plateState[plate]; if old then hideState(old) end
  return
 end
 local s=stateFor(plate)
 local d=db(); if not d.enabled or (rel=='ENEMY' and not d.enemy) or (rel=='FRIEND' and not d.friendly) then hideState(s); return end
 local list={}; for _,e in pairs(bucket) do if allowed(e.cat,rel) then list[#list+1]=e end end
 if #list==0 then hideState(s); return end
 table.sort(list,function(a,b) return a.expire<b.expire end)
 local f=s.frame; f:ClearAllPoints(); f:SetPoint('BOTTOM',plate,'TOP',0,8)
 local x=0
 for i,e in ipairs(list) do
  -- Compact icon-only nameplate display: identical icon/countdown behavior to Target Frame.
  -- Only update existing tracked cooldowns; no nameplate scans or aura rebuilds.
  local b=itemFor(s,i); local size=d.iconSize
  b._spellID=e.id
  b:SetSize(size,size); b:ClearAllPoints(); b:SetPoint('LEFT',f,'LEFT',x,0)
  b.icon:ClearAllPoints(); b.icon:SetAllPoints(b); b.icon:SetTexture(spellTexture(e.id))
  b.cd:ClearAllPoints(); b.cd:SetAllPoints(b.icon); b.cd:SetCooldown(e.started,e.duration)
  b._trackerExpire=e.expire; styleTrackerCountdown(b)
  b.name:SetText(''); b.name:Hide()
  b:Show(); x=x+size+d.spacing
 end
 for i=#list+1,#s.items do s.items[i]._spellID=nil; s.items[i]:Hide() end
 f:SetSize(math.max(1,x-d.spacing),d.iconSize); f:Show()
end
-- Resolve the visible unit-frame anchor only when the target tracker actually renders.
-- Do not poll frames, alter TPerl, or touch nameplate/aura processing.
local function trackerTargetAnchorFrame()
 local tperl = _G.TPerl_Target
 if tperl and tperl.IsShown and tperl:IsShown() then
  return tperl
 end
 return _G.TargetFrame or UIParent
end
local function targetFrameState()
 if targetDisplay then return targetDisplay end
 local parent=UIParent
 local f=CreateFrame('Frame',nil,parent); f:SetFrameStrata('HIGH'); f:EnableMouse(false); f.items={}; f:Hide()
 targetDisplay={frame=f,items=f.items,isTarget=true}
 return targetDisplay
end
local function refreshTarget()
 local s=targetDisplay
 local unit=trackerDisplayUnit()
 local rel=unit and trackerRelation(unit); local guid=unit and safeGUID(unit)
 if not rel or not guid then if s then hideState(s) end; return end
 cleanupBucket(guid)
 local bucket=active[guid]
 if not bucket then if s then hideState(s) end; return end
 local d=db(); if not d.targetEnabled then if s then hideState(s) end; return end
 local list={}
 for _,e in pairs(bucket) do
  if (e.isTest or allowed(e.cat,rel)) and (tonumber(e.duration) or 0) >= (tonumber(d.targetMinCD) or 0) then list[#list+1]=e end
 end
 if #list==0 then if s then hideState(s) end; return end
 local priority={DEF=1,INT=2,CC=3,OFF=4,MOB=5}
 if d.targetSort=='PRIORITY' then
  table.sort(list,function(a,b) local ap=priority[a.cat] or 9; local bp=priority[b.cat] or 9; if ap~=bp then return ap<bp end return a.expire<b.expire end)
 elseif d.targetSort=='CATEGORY' then
  table.sort(list,function(a,b) if a.cat~=b.cat then return tostring(a.cat)<tostring(b.cat) end return a.expire<b.expire end)
 else table.sort(list,function(a,b) return a.expire<b.expire end) end
 local maxIcons=math.max(1,math.min(40,tonumber(d.targetMaxIcons) or 16))
 while #list>maxIcons do table.remove(list) end
 s=targetFrameState(); local f=s.frame; f:ClearAllPoints()
 local anchor=d.targetAnchor or TARGET_DEFAULT_ANCHOR; local opposite=anchor=='TOP' and 'BOTTOM' or anchor=='LEFT' and 'RIGHT' or anchor=='RIGHT' and 'LEFT' or 'TOP'
 f:SetPoint(anchor,trackerTargetAnchorFrame(),opposite,tonumber(d.targetX) or TARGET_DEFAULT_X,tonumber(d.targetY) or TARGET_DEFAULT_Y)
 local size=math.max(16,math.min(64,tonumber(d.targetIconSize) or d.iconSize or 30))
 local gap=math.max(0,math.min(20,tonumber(d.targetSpacing) or 4)); local perRow=math.max(1,math.min(20,tonumber(d.targetPerRow) or 8))
 local cols=math.min(perRow,#list); local rows=math.ceil(#list/perRow)
 for i,e in ipairs(list) do
  local b=itemFor(s,i); b._spellID=e.id; b:SetSize(size,size); b:ClearAllPoints()
  local n=i-1; local col=n%perRow; local row=math.floor(n/perRow)
  local x=(d.targetGrowth=='LEFT' and -1 or 1)*col*(size+gap)
  local y=(d.targetRowGrowth=='DOWN' and -1 or 1)*row*(size+gap)
  local point=(d.targetGrowth=='LEFT') and 'RIGHT' or 'LEFT'
  b:SetPoint(point,f,point,x,y)
  b.icon:ClearAllPoints(); b.icon:SetAllPoints(b); b.icon:SetTexture(spellTexture(e.id))
  b.cd:ClearAllPoints(); b.cd:SetAllPoints(b.icon); b.cd:SetCooldown(e.started,e.duration)
  b._trackerExpire=e.expire; styleTrackerCountdown(b)
  b.name:SetText(''); b.name:Hide()
  b:Show()
 end
 for i=#list+1,#s.items do s.items[i]._spellID=nil; s.items[i]:Hide() end
 f:SetSize(math.max(1,cols*size+(cols-1)*gap),math.max(1,rows*size+(rows-1)*gap)); f:Show()
end
-- Cooldown-triggered handoff: locate an existing visible nameplate for the
-- detected GUID. This runs ONLY after an observed cooldown / target transition,
-- never on camera movement, and never creates new aura containers.
local function reconnectCooldownNameplate(guid)
 if not guid or not accessible(guid) then return end
 local known=guidToUnit[guid]
 if type(known)=='string' and known:match('^nameplate%d+$') and safeGUID(known)==guid then
  local plate=unitToPlate[known] or getPlate(known)
  if plate then unitToPlate[known]=plate; refreshUnit(known); return end
 end
 if not C_NamePlate then return end
 local plate=getPlate('target')
 if not plate and type(C_NamePlate.GetNamePlates)=='function' then
  -- Bounded lookup on an ACTUAL tracked activation, not a camera/nameplate event.
  -- Do not allocate frames or invoke aura population during this lookup.
  local ok,plates=pcall(C_NamePlate.GetNamePlates)
  if ok and type(plates)=='table' then
   for _,candidate in ipairs(plates) do
    local token=candidate and (candidate.namePlateUnitToken or candidate.unitToken or (candidate.UnitFrame and candidate.UnitFrame.unit))
    if type(token)=='string' and token:match('^nameplate%d+$') and safeGUID(token)==guid then
     plate=candidate; break
    end
   end
  end
 end
 if not plate then return end
 local unit=plate.namePlateUnitToken or plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
 if type(unit)~='string' or not unit:match('^nameplate%d+$') then return end
 if safeGUID(unit)~=guid then return end
 unitToPlate[unit]=plate; guidToUnit[guid]=unit
 refreshUnit(unit)
end
local function bindCurrentTargetNameplate(guid)
 reconnectCooldownNameplate(guid)
end

local function rememberObservedTargetAura(id,auraDuration,auraExpiration,auraInstanceID)
 local spec=resolveObservedSpell(id); if not spec then return end
 local rel=targetRelation(); if not rel or not allowed(spec[2],rel) then return end
 local guid=safeGUID('target'); if not guid then return end
 local now=GetTime(); local cd=spec[1]
 local remaining=(type(auraExpiration)=='number' and accessible(auraExpiration)) and math.max(0,auraExpiration-now) or nil
 local activeDur=(type(auraDuration)=='number' and accessible(auraDuration) and auraDuration>0) and auraDuration or nil
 local elapsed=(remaining and activeDur) and math.max(0,activeDur-remaining) or 0
 local started=now-elapsed
 active[guid]=active[guid] or {}
 local old=active[guid][id]
 -- Same aura instance / same activation: never restart the predicted cooldown on UNIT_AURA spam.
 if old then
  if auraInstanceID and old.auraInstanceID==auraInstanceID then return end
  if not auraInstanceID and old.observedAuraExpire and auraExpiration and math.abs(old.observedAuraExpire-auraExpiration)<0.15 then return end
 end
 -- If the successful-cast observer already saw this same activation, keep its original start.
 if old and old.source=='CAST' and old.started and math.abs(started-old.started)<2.5 then
  old.auraInstanceID=auraInstanceID; old.observedAuraExpire=auraExpiration; refreshTarget(); return
 end
 local e={id=id,started=started,expire=started+cd,duration=cd,cat=spec[2],rel=rel,source='AURA',auraInstanceID=auraInstanceID,observedAuraExpire=auraExpiration}
 active[guid][id]=e
 scheduleExpiry(guid,id,e.expire)
 announce()
 bindCurrentTargetNameplate(guid)
end
-- SECOND OBSERVER: successful casts by the CURRENT TARGET only.
-- This is intentionally not a world/nameplate cast scanner.  If Blizzard exposes a readable
-- spellID for target UNIT_SPELLCAST_SUCCEEDED, feed it into the same GUID state used by auras.
-- Abilities observed by BOTH paths are deduplicated so a resulting self-buff cannot restart
-- a cooldown that was just started by the successful cast.
local function rememberObservedTargetCast(id)
 id=safeNumber(id); if not id then return end
 local spec=resolveObservedSpell(id); if not spec then return end
 local rel=targetRelation(); if not rel or not allowed(spec[2],rel) then return end
 local guid=safeGUID('target'); if not guid then return end
 local now=GetTime(); local cd=spec[1]
 active[guid]=active[guid] or {}
 local old=active[guid][id]
 -- SAME activation may be visible as CAST + AURA. Never restart it.
 if old and old.started and math.abs(now-old.started)<2.5 then return end
 cd=observedCastDuration(guid,id,cd,now)
 local e={id=id,started=now,expire=now+cd,duration=cd,cat=spec[2],rel=rel,source='CAST'}
 active[guid][id]=e
 scheduleExpiry(guid,id,e.expire)
 announce()
 refreshTarget()
 bindCurrentTargetNameplate(guid)
end

-- FOREVER/MIDNIGHT visible-unit cast observer. This does NOT scan nameplates and does not
-- participate in NAME_PLATE_UNIT_ADDED. It only reacts when Blizzard itself reports a
-- successful cast for an already-addressable unit token (target/nameplateN/etc.). This is
-- what lets short CDs such as Charge be learned even when that warrior is not our target.
local function rememberObservedUnitCast(unit,id)
 if type(unit)~='string' then return end
 id=safeNumber(id); if not id then return end
 local spec=resolveObservedSpell(id); if not spec then return end
 -- Nameplate tokens use the existing lightweight relation path; target and
 -- mouseover are valid event-supplied units too.  Never enumerate plates.
 local rel=relation(unit)
 if not rel and (unit=='target' or unit=='mouseover') then rel=trackerRelation(unit) end
 if not rel or not allowed(spec[2],rel) then return end
 local guid=safeGUID(unit); if not guid then return end
 local now=GetTime(); local cd=spec[1]
 active[guid]=active[guid] or {}
 local old=active[guid][id]
 if old and old.started and math.abs(now-old.started)<2.5 then return end
 cd=observedCastDuration(guid,id,cd,now)
 local e={id=id,started=now,expire=now+cd,duration=cd,cat=spec[2],rel=rel,source='CAST'}
 active[guid][id]=e
 guidToUnit[guid]=unit
 -- Resolve/paint only THIS caster, only because a tracked spell actually fired. No camera work.
 local plate=unit:match('^nameplate%d+$') and getPlate(unit)
 if plate then unitToPlate[unit]=plate; refreshUnit(unit) end
 scheduleExpiry(guid,id,e.expire)
 announce()
 if safeGUID('target')==guid then bindCurrentTargetNameplate(guid) end
 if safeGUID(trackerDisplayUnit())==guid then refreshTarget() end
end

local function scanTrackerHelpfulAuras(unit)
 if type(unit)~='string' or not db().enabled or not trackerRelation(unit) then return end
 local getter=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if type(getter)~='function' then return end
 for i=1,40 do
  local ok,a=pcall(getter,unit,i,'HELPFUL')
  if not ok or type(a)~='table' then break end
  local id=safeNumber(field(a,'spellId') or field(a,'spellID'))
  local spec=id and resolveObservedSpell(id)
  if spec then
   local rel=trackerRelation(unit); local guid=safeGUID(unit)
   if rel and guid and allowed(spec[2],rel) then
    local dur=safeNumber(field(a,'duration')); local exp=safeNumber(field(a,'expirationTime')); local inst=safeNumber(field(a,'auraInstanceID'))
    local now=GetTime(); local remaining=exp and math.max(0,exp-now) or nil; local activeDur=(dur and dur>0) and dur or nil
    local started=now-((remaining and activeDur) and math.max(0,activeDur-remaining) or 0)
    active[guid]=active[guid] or {}; local old=active[guid][id]
    if not (old and ((inst and old.auraInstanceID==inst) or (exp and old.observedAuraExpire and math.abs(exp-old.observedAuraExpire)<0.15) or (old.started and math.abs(started-old.started)<2.5))) then
     local e={id=id,started=started,expire=started+spec[1],duration=spec[1],cat=spec[2],rel=rel,source='AURA',auraInstanceID=inst,observedAuraExpire=exp}
     active[guid][id]=e; scheduleExpiry(guid,id,e.expire)
     -- A genuinely new observed player buff (e.g. Rogue Stealth) must use the
     -- same sound path as a successful cast. Repeated UNIT_AURA is deduplicated.
     announce()
    end
   end
  end
 end
end

local function reconnectObservedUnitPlate(unit)
 -- RENDER HANDOFF ONLY: reconnect one already-addressable observed unit to its existing
 -- nameplate when that GUID already has cooldown state. No enumeration, no polling, no OnUpdate.
 if type(unit)~='string' then return end
 local guid=safeGUID(unit); if not guid or not active[guid] then return end
 local plate=getPlate(unit); if not plate then return end
 local plateUnit=plate.namePlateUnitToken or plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
 if type(plateUnit)=='string' and plateUnit:match('^nameplate%d+$') and safeGUID(plateUnit)==guid then
  unitToPlate[plateUnit]=plate; guidToUnit[guid]=plateUnit; refreshUnit(plateUnit)
 elseif unit:match('^nameplate%d+$') then
  unitToPlate[unit]=plate; guidToUnit[guid]=unit; refreshUnit(unit)
 end
end

-- Explicit aura-effect -> cast mapping. Keep these deliberately conservative: only
-- effects that identify a particular cooldown. Never infer a caster from the victim.
-- On Forever, the rank-specific Flame Shock/Stormstrike effects normally share the
-- cast ID; this table also documents effect IDs that differ from their cast.
local effectToCast = {
 [17364]=17364, -- Stormstrike's identifiable debuff, where exposed
 [8050]=8050,[8052]=8052,[8053]=8053,[10447]=10447,[10448]=10448,
 [8056]=8056,[8058]=8058,[10472]=10472,[10473]=10473,
 [122]=122,[865]=865,[6131]=6131,[10230]=10230, -- Frost Nova ranks
}
local function resolveEffect(id)
 if not id then return end
 local castID=effectToCast[id] or id
 local spec=spells[castID] -- never infer unknown cooldowns from unrelated debuffs
 if not spec then return end
 return castID,spec
end

-- Victim-side evidence observer. A hostile player's debuff can prove a cast even
-- when UNIT_SPELLCAST_SUCCEEDED is not delivered for that hostile unit.
-- This is bounded and event-driven; it never enumerates nameplates or creates frames.
local function scanVictimHarmfulAuras(unit)
 if type(unit)~='string' or not db().enabled then return end
 if safeBool(UnitExists,unit)~=true then return end
 local getter=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if type(getter)~='function' then return end
 for i=1,40 do
  local ok,a=pcall(getter,unit,i,'HARMFUL')
  if not ok or type(a)~='table' then break end
  local id=safeNumber(field(a,'spellId') or field(a,'spellID'))
  local castID,spec=resolveEffect(id)
  if spec then
   local caster=field(a,'sourceUnit')
   -- Never attribute an aura to our target merely because the victim is targettarget.
   -- The actual source unit must be provided by Blizzard and have a readable GUID.
   if type(caster)=='string' and accessible(caster) then
    local guid=safeGUID(caster)
    local rel=trackerRelation(caster)
    if guid and rel and allowed(spec[2],rel) then
     local inst=safeNumber(field(a,'auraInstanceID'))
     local exp=safeNumber(field(a,'expirationTime'))
     local now=GetTime()
     active[guid]=active[guid] or {}
     local old=active[guid][castID]
     -- Auras are not casts: never restart the timer on refresh or repeated events.
     if not (old and ((inst and old.auraInstanceID==inst) or
          (exp and old.observedAuraExpire and math.abs(exp-old.observedAuraExpire)<0.15) or
          (old.started and now-old.started>=0 and now-old.started<2.5))) then
      local e={id=castID,started=now,expire=now+spec[1],duration=spec[1],
       cat=spec[2],rel=rel,source='VICTIM_AURA',auraInstanceID=inst,observedAuraExpire=exp}
      active[guid][castID]=e
      scheduleExpiry(guid,castID,e.expire)
      announce()
      reconnectObservedUnitPlate(caster)
      if safeGUID(trackerDisplayUnit())==guid then refreshTarget() end
     end
    end
   end
  end
 end
end

local function scanCurrentTargetHelpfulAuras()
 scanTrackerHelpfulAuras('target')
 if not db().enabled or not targetRelation() then refreshTarget(); return end
 local getter=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if type(getter)~='function' then refreshTarget(); return end
 -- Bounded current-target-only scan. No nameplate enumeration and no polling.
 for i=1,40 do
  local ok,a=pcall(getter,'target',i,'HELPFUL')
  if not ok or type(a)~='table' then break end
  local id=field(a,'spellId') or field(a,'spellID')
  id=safeNumber(id)
  if id and spells[id] then
   local dur=safeNumber(field(a,'duration'))
   local exp=safeNumber(field(a,'expirationTime'))
   local inst=safeNumber(field(a,'auraInstanceID'))
   rememberObservedTargetAura(id,dur,exp,inst)
  end
 end
 refreshTarget()
end

local function refreshKnownVisible()
 -- Only units we already learned from NAME_PLATE_UNIT_ADDED; never scan nameplate1..40.
 for unit in pairs(unitToPlate) do refreshUnit(unit) end
end
scheduleExpiry=function(guid,id,expire)
 if not C_Timer or not C_Timer.After then return end
 local delay=math.max(0.05,expire-GetTime()+0.10)
 C_Timer.After(delay,function()
  local bucket=active[guid]; local e=bucket and bucket[id]
  if e and e.expire<=GetTime()+0.02 then bucket[id]=nil; if not next(bucket) then active[guid]=nil end end
  local unit=guidToUnit[guid]; if unit then refreshUnit(unit) end
  if safeGUID(trackerDisplayUnit())==guid then refreshTarget() end
 end)
end
local lastTrackerSound=0
announce=function()
 local d=db(); if not d.enabled or not d.sounds then return end
 -- One alert per short burst, not one per aura/rank/icon or UNIT_AURA refresh.
 local now=GetTime()
 if now-lastTrackerSound<0.35 then return end
 lastTrackerSound=now
 local played=false
 if PlaySoundFile then
  local ok,result=pcall(PlaySoundFile,AURA_SOUND_FILE,'Master')
  played=ok and result~=false
 end
 if not played and PlaySound then
  pcall(PlaySound,(SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK)) or 8960,'Master')
 end
end
local function add(unit,id,dur,cat,isTest)
 local rel=relation(unit); if not rel or not allowed(cat,rel) then return end
 local guid=safeGUID(unit); if not guid then return end
 local now=GetTime(); active[guid]=active[guid] or {}
 local e={id=id,started=now,expire=now+dur,duration=dur,cat=cat,rel=rel,isTest=isTest}
 active[guid][id]=e; guidToUnit[guid]=unit
 refreshUnit(unit); scheduleExpiry(guid,id,e.expire); if not isTest then announce() end
 if safeGUID('target')==guid then bindCurrentTargetNameplate(guid) end
 if safeGUID(trackerDisplayUnit())==guid then refreshTarget() end
end
local pendingTrackerPlates, trackerPlateQueue, trackerPlateScheduled = {}, {}, false
local trackerPlateHead = 1
local function drainTrackerPlates()
 trackerPlateScheduled=false
 local unit=trackerPlateQueue[trackerPlateHead]
 trackerPlateQueue[trackerPlateHead]=false
 trackerPlateHead=trackerPlateHead+1
 if unit then
  local guid=pendingTrackerPlates[unit]
  pendingTrackerPlates[unit]=nil
  -- A queued token may already have been recycled or disappeared.
  if guid and safeGUID(unit)==guid and active[guid] then
   local plate=getPlate(unit)
   if plate then unitToPlate[unit]=plate; guidToUnit[guid]=unit; refreshUnit(unit) end
  end
 end
 if trackerPlateHead<=#trackerPlateQueue and C_Timer and C_Timer.After then
  trackerPlateScheduled=true; C_Timer.After(0,drainTrackerPlates)
 else
  trackerPlateQueue={}; trackerPlateHead=1
 end
end
local function onPlateAdded(unit)
 if type(unit)~='string' then return end
 -- Sounds use Blizzard's engine-side aura matcher.  With Sounds OFF this is one boolean check.
 -- PERFORMANCE LOCK: never register engine-side aura sounds from NAME_PLATE_UNIT_ADDED.
 -- Sound alerts use the already-observed cooldown event path (announce()).
 -- ZERO-IDLE HOT PATH: until at least one real/test cooldown exists there is
 -- absolutely nothing for this module to reconnect. Camera turns in a city can
 -- generate a large burst of NAME_PLATE_UNIT_ADDED events; previously each one
 -- still called GetNamePlateForUnit + UnitGUID even though active was empty.
 if not next(active) then return end
 -- CAMERA HOT PATH: reject unrelated plates by GUID before resolving a frame.
 local guid=safeGUID(unit)
 if not guid or not active[guid] then return end
 if pendingTrackerPlates[unit] or unitToPlate[unit] then return end
 if not C_Timer or not C_Timer.After then
  local plate=getPlate(unit); if plate then unitToPlate[unit]=plate; guidToUnit[guid]=unit; refreshUnit(unit) end
  return
 end
 pendingTrackerPlates[unit]=guid
 trackerPlateQueue[#trackerPlateQueue+1]=unit
 if not trackerPlateScheduled then trackerPlateScheduled=true; C_Timer.After(0,drainTrackerPlates) end
end
local function onPlateRemoved(unit)
 if type(unit)~='string' then return end
 pendingTrackerPlates[unit]=nil
 removeAuraSounds(unit)
 -- If this token was never relevant to an active cooldown, removal is a no-op.
 local plate=unitToPlate[unit]; if not plate then return end
 hideState(plateState[plate])
 local guid=safeGUID(unit); if guid and guidToUnit[guid]==unit then guidToUnit[guid]=nil end
 unitToPlate[unit]=nil
end


-- FOREVER hostile-cast backstop -------------------------------------------------
-- UNIT_SPELLCAST_SUCCEEDED is not emitted consistently for every hostile instant
-- ability in Forever (notably Shocks/Stormstrike/Charge and some Hunter/Warlock
-- actions).  The combat log *does* report SPELL_CAST_SUCCESS.  This is event-only:
-- no scan, no OnUpdate, no nameplate enumeration and no AuraContainer work.
local function rememberObservedGUIDCast(guid,id)
 if type(guid)~='string' or not accessible(guid) then return end
 id=safeNumber(id); if not id then return end
 local spec=resolveObservedSpell(id); if not spec then return end
 local unit
 if safeGUID('target')==guid then unit='target'
 elseif safeGUID('mouseover')==guid then unit='mouseover'
 else unit=guidToUnit[guid] end
 if not unit then return end -- only a unit GODMODE already knows; never world-track strangers
 local rel=(unit=='target' and targetRelation()) or (unit=='mouseover' and trackerRelation('mouseover')) or relation(unit)
 if not rel or not allowed(spec[2],rel) then return end
 local now=GetTime(); active[guid]=active[guid] or {}
 local old=active[guid][id]
 if old and old.started and math.abs(now-old.started)<2.5 then return end
 local duration=observedCastDuration(guid,id,spec[1],now)
 local e={id=id,started=now,expire=now+duration,duration=duration,cat=spec[2],rel=rel,source='CLEU'}
 active[guid][id]=e; guidToUnit[guid]=unit
 scheduleExpiry(guid,id,e.expire); announce()
 reconnectCooldownNameplate(guid)
 if safeGUID(trackerDisplayUnit())==guid then refreshTarget() end
end
local function onForeverCombatLog()
 if type(CombatLogGetCurrentEventInfo)~='function' then return end
 local ok,_,subevent,_,sourceGUID,_,_,_,_,_,_,spellID=pcall(CombatLogGetCurrentEventInfo)
 if not ok or not accessible(subevent) or subevent~='SPELL_CAST_SUCCESS' then return end
 if not accessible(sourceGUID) or not accessible(spellID) then return end
 rememberObservedGUIDCast(sourceGUID,spellID)
end
-- FOREVER: observe Blizzard's existing combat-log processing instead of trying
-- to register the protected COMBAT_LOG_EVENT_UNFILTERED event on our own frame.
-- Neither hook creates an event listener or changes Blizzard's combat-log filters.
-- These are optional, independent bridges: unavailable APIs simply leave the
-- already-working target/mouseover/nameplate/aura observers in place.
local function installForeverCombatLogBridge()
 if iface ~= 16001 then return end
 local installed = false
 if type(hooksecurefunc)=='function' and type(CombatLog_OnEvent)=='function' then
  local ok=pcall(hooksecurefunc,'CombatLog_OnEvent',function(_,event)
   if event=='COMBAT_LOG_EVENT_UNFILTERED' then onForeverCombatLog() end
  end)
  if ok then installed=true end
 end
 -- Combat-log message filters receive the combat-log event payload from the
 -- default Blizzard combat log. Return false so the original log stays visible.
 -- Use this as a fallback when the normal Blizzard handler isn't hookable.
 if not installed and type(CombatLogAddMessageEventFilter)=='function' then
  pcall(CombatLogAddMessageEventFilter,'SPELL_CAST_SUCCESS',function(_, ...)
   local args={...}
   -- Standard CLEU message filter arguments: timestamp, subevent, hideCaster,
   -- sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, ... spellID.
   local subevent=args[2]
   local sourceGUID=args[4]
   local spellID=args[12]
   if accessible(subevent) and subevent=='SPELL_CAST_SUCCESS' and
      accessible(sourceGUID) and accessible(spellID) then
    rememberObservedGUIDCast(sourceGUID,spellID)
   else
    -- API payload layouts vary; use the current Blizzard combat-log event.
    onForeverCombatLog()
   end
   return false
  end)
 end
end
installForeverCombatLogBridge()

-- End Forever hostile-cast backstop -------------------------------------------

local ev=CreateFrame('Frame')
ev:SetScript('OnEvent',function(_,event,...)
 if event=='COMBAT_LOG_EVENT_UNFILTERED' then onForeverCombatLog(); return end
 if event=='NAME_PLATE_UNIT_ADDED' then onPlateAdded((...)); return end
 if event=='NAME_PLATE_UNIT_REMOVED' then onPlateRemoved((...)); return end
 if event=='PLAYER_TARGET_CHANGED' then scanCurrentTargetHelpfulAuras(); scanVictimHarmfulAuras('target'); scanVictimHarmfulAuras('targettarget'); reconnectObservedUnitPlate('target'); local g=safeGUID('target'); if g and active[g] then reconnectCooldownNameplate(g) end; refreshTarget(); return end
 if event=='UPDATE_MOUSEOVER_UNIT' then scanTrackerHelpfulAuras('mouseover'); reconnectObservedUnitPlate('mouseover'); refreshTarget(); return end
 if event=='UNIT_AURA' then
  local unit=(...)
  if unit=='target' then scanCurrentTargetHelpfulAuras(); reconnectObservedUnitPlate('target')
  elseif unit=='mouseover' or unit=='focus' then scanTrackerHelpfulAuras(unit); reconnectObservedUnitPlate(unit); refreshTarget() end
  -- Nameplate aura events are a detection source, not a rendering/binding trigger.
  -- Only the event-supplied unit is inspected; the existing camera governor stays untouched.
  if type(unit)=='string' and unit:match('^nameplate%d+$') then
   scanTrackerHelpfulAuras(unit)
   scanVictimHarmfulAuras(unit)
   reconnectObservedUnitPlate(unit)
  end
  if unit=='player' or unit=='target' or unit=='targettarget' or unit=='focus' or
     unit=='mouseover' or (type(unit)=='string' and (unit:match('^party%d+$') or unit:match('^raid%d+$'))) then
   scanVictimHarmfulAuras(unit)
  end
  return
 end
 if event=='PLAYER_FOCUS_CHANGED' then scanTrackerHelpfulAuras('focus'); scanVictimHarmfulAuras('focus'); return end
 if event=='UNIT_TARGET' then local unit=(...); if unit=='target' then scanVictimHarmfulAuras('targettarget'); scanTrackerHelpfulAuras('targettarget') end; return end
 if event=='UNIT_SPELLCAST_SUCCEEDED' then
  local unit,castGUID,spellID=...
  -- Do not require castGUID: on Forever it may be secret/restricted even when unit+spellID
  -- are readable. The spellID is validated against our static cooldown DB before any work.
  if unit=='target' then rememberObservedTargetCast(spellID)
  else rememberObservedUnitCast(unit,spellID) end
  return
 end
end)
-- PERFORMANCE-SAFE OBSERVERS: event-driven visible-unit casts only. No nameplate enumeration,
-- no ticker and no OnUpdate. The locked NAME_PLATE_UNIT_ADDED governor remains untouched.
ev:RegisterEvent('NAME_PLATE_UNIT_ADDED')
ev:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
ev:RegisterEvent('PLAYER_TARGET_CHANGED')
ev:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
ev:RegisterEvent('UNIT_AURA')
ev:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
ev:RegisterEvent('PLAYER_FOCUS_CHANGED')
ev:RegisterEvent('UNIT_TARGET')
-- Midnight: try the documented event only on clients where registration is accepted.
-- Forever previously raised ADDON_ACTION_FORBIDDEN even when guarded: NEVER register there.
-- No polling, no Blizzard frame hooks, no taint-bypass mechanisms.
 -- Do not register COMBAT_LOG_EVENT_UNFILTERED on Midnight either.
 -- The client can report ADDON_ACTION_FORBIDDEN even through pcall.
 -- Preserve the combat-log processing function above and all existing
 -- UNIT_SPELLCAST_SUCCEEDED, UNIT_AURA, target and nameplate observers.
 -- This protected event path remains inactive until a permitted API exists.
-- Combat log backstop remains intentionally dormant on protected clients.
-- Registering COMBAT_LOG_EVENT_UNFILTERED here previously produced ADDON_ACTION_FORBIDDEN.
-- Do not hook protected Blizzard event handlers to bypass this restriction.
-- Forever forbids COMBAT_LOG_EVENT_UNFILTERED registration for addon code.
-- Do not attempt it, even through pcall or a delayed callback: blocked actions
 -- still taint and trigger ADDON_ACTION_FORBIDDEN. Keep the original
 -- UNIT_SPELLCAST_SUCCEEDED and aura observation paths intact.

local API={}
function API:RefreshThemeAppearance()
 for _,state in pairs(plateState) do
  if state and state.items then for _,b in ipairs(state.items) do if b:IsShown() then styleTrackerCountdown(b) end end end
 end
 if targetDisplay and targetDisplay.items then
  for _,b in ipairs(targetDisplay.items) do if b:IsShown() then styleTrackerCountdown(b) end end
 end
end
function API:IsEnabled() return db().enabled end
local function stateMsg(label,v)
 print('|cffd8a52bGODMODE:|r '..label..' '..(v and '|cff35ff62ON|r' or '|cffff4b4bOFF|r'))
end
function API:SetEnabled(v) db().enabled=not not v; removeAllAuraSounds(); refreshKnownVisible(); refreshTarget(); stateMsg('Player Cooldown Tracker',db().enabled) end
function API:GetEnemy() return db().enemy end
function API:SetEnemy(v) db().enemy=not not v; refreshKnownVisible(); refreshTarget(); stateMsg('Enemy Players',db().enemy) end
function API:GetFriendly() return db().friendly end
function API:SetFriendly(v) db().friendly=not not v; refreshKnownVisible(); refreshTarget(); stateMsg('Friendly Players',db().friendly) end
function API:GetSounds() return db().sounds end
function API:SetSounds(v)
 db().sounds=not not v
 -- Event-observed cast/aura alerts only: no per-nameplate registrations,
 -- no global nameplate scan and no permanent OnUpdate.
 removeAllAuraSounds()
 stateMsg('Player Cooldown Sound Alerts',db().sounds)
end
function API:IsLocked() return true end
function API:SetLocked() end
function API:Nudge() end
function API:ResetPosition() end
function API:NudgeSize(delta) local d=db(); d.iconSize=math.max(20,math.min(48,d.iconSize+(delta or 0))); refreshKnownVisible() end
local function targetPlayerUnit()
 local plate=getPlate('target'); if not plate then return end
 local u=plate.namePlateUnitToken or plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
 if type(u)=='string' and relation(u) then return u end
 -- If Blizzard doesn't expose the token on the frame, use only already-known lifecycle mappings.
 for unit,p in pairs(unitToPlate) do if p==plate and relation(unit) then return unit end end
end
function API:Test()
 local rel=targetRelation()
 local guid=safeGUID('target')
 if not rel or not guid then
  print('|cffd8a52bGODMODE:|r Target a friendly or enemy PLAYER to test Target Cooldowns.')
  return
 end
 active[guid]=active[guid] or {}
 for id,e in pairs(active[guid]) do if e.isTest then active[guid][id]=nil end end

 -- Stable 12-icon preview: enough icons to visibly test Size, Spacing, Per Row,
 -- Max Icons, Min CD, Growth, Row Growth and Sort. No nameplate is required.
 local ids={642,1766,2983,853,96231,1044,31884,8122,17928,17364,2687,17}
 local secs={120,5,12,60,15,25,90,30,40,8,60,7.5}
 local cats={'DEF','INT','MOB','CC','INT','MOB','OFF','CC','CC','OFF','OFF','DEF'}
 local now=GetTime()
 for i,id in ipairs(ids) do
  local dur=secs[i]
  active[guid][id]={id=id,started=now,expire=now+dur,duration=dur,cat=cats[i],rel=rel,isTest=true}
  scheduleExpiry(guid,id,now+dur)
 end
 refreshTarget()
end
function API:SetCategory(cat,v) local d=db(); if cat=='INT' then d.interrupts=v elseif cat=='DEF' then d.defensives=v elseif cat=='OFF' then d.offensives=v elseif cat=='CC' then d.cc=v elseif cat=='MOB' then d.mobility=v end; refreshKnownVisible(); refreshTarget() end
function API:GetCategory(cat) local d=db(); return cat=='INT' and d.interrupts or cat=='DEF' and d.defensives or cat=='OFF' and d.offensives or cat=='CC' and d.cc or cat=='MOB' and d.mobility end
function API:GetNameplateEnabled() return db().nameplateEnabled~=false end
function API:SetNameplateEnabled(v)
 db().nameplateEnabled=not not v
 -- Only known visible plates; never touch the Target Frame or tracking database.
 refreshKnownVisible()
end
function API:GetTargetEnabled() local d=db(); return d.targetEnabled~=false end
function API:GetTargetMouseover() local d=db(); return d.targetMouseover~=false end
function API:SetTargetMouseover(v) db().targetMouseover=not not v; refreshTarget() end
function API:SetTargetEnabled(v) db().targetEnabled=not not v; refreshTarget() end
function API:GetTargetIconSize() return db().targetIconSize end
function API:SetTargetIconSize(v) db().targetIconSize=math.max(16,math.min(64,tonumber(v) or 30)); refreshTarget() end
function API:GetTargetSpacing() return db().targetSpacing end
function API:SetTargetSpacing(v) db().targetSpacing=math.max(0,math.min(20,tonumber(v) or 4)); refreshTarget() end
function API:GetTargetPerRow() return db().targetPerRow end
function API:SetTargetPerRow(v) db().targetPerRow=math.max(1,math.min(20,math.floor(tonumber(v) or 8))); refreshTarget() end
function API:GetTargetMaxIcons() return db().targetMaxIcons end
function API:SetTargetMaxIcons(v) db().targetMaxIcons=math.max(1,math.min(40,math.floor(tonumber(v) or 16))); refreshTarget() end
function API:GetTargetMinCD() return db().targetMinCD end
function API:SetTargetMinCD(v) db().targetMinCD=math.max(0,math.min(600,tonumber(v) or 0)); refreshTarget() end
function API:GetTargetX() return db().targetX end
function API:SetTargetX(v) db().targetX=math.max(-500,math.min(500,tonumber(v) or 0)); refreshTarget() end
function API:GetTargetY() return db().targetY end
function API:SetTargetY(v) db().targetY=math.max(-500,math.min(500,tonumber(v) or 10)); refreshTarget() end
function API:GetTargetAnchor() return db().targetAnchor end
function API:SetTargetAnchor(v) if v=='TOP' or v=='BOTTOM' or v=='LEFT' or v=='RIGHT' then db().targetAnchor=v; refreshTarget() end end
function API:GetTargetGrowth() return db().targetGrowth end
function API:SetTargetGrowth(v) if v=='LEFT' or v=='RIGHT' then db().targetGrowth=v; refreshTarget() end end
function API:GetTargetRowGrowth() return db().targetRowGrowth end
function API:SetTargetRowGrowth(v) if v=='UP' or v=='DOWN' then db().targetRowGrowth=v; refreshTarget() end end
function API:GetTargetSort() return db().targetSort end
function API:SetTargetSort(v) if v=='TIME' or v=='PRIORITY' or v=='CATEGORY' then db().targetSort=v; refreshTarget() end end
function API:ResetTargetLayout() local d=db(); d.targetIconSize=30; d.targetSpacing=4; d.targetPerRow=8; d.targetMaxIcons=16; d.targetMinCD=0; d.targetX=TARGET_DEFAULT_X; d.targetY=TARGET_DEFAULT_Y; d.targetAnchor=TARGET_DEFAULT_ANCHOR; d.targetGrowth='RIGHT'; d.targetRowGrowth='UP'; d.targetSort='TIME'; refreshTarget() end
function API:GetTrackedSpellCount() local n=0; for _ in pairs(spells) do n=n+1 end; return n end
Addon.EnemyCooldowns=API; Addon.PlayerCooldowns=API
_G.OmniCC_GODMODE_EnemyCooldownsAPI=API; _G.OmniCC_GODMODE_PlayerCooldownsAPI=API
