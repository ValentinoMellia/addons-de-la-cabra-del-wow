local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
-- Forever 70170+: do not gate on WOW_PROJECT_ID; the Camelot TOC + interface 16001 are authoritative.
local AddonName, Addon = ...

-- Compatibility Center ownership contract (Forever 1.2.8)
-- Master OFF = GODMODE owns every scope, regardless of remembered checkboxes.
-- Master ON  = only the explicitly checked scopes are released.
local SCOPES = {'player','target','targetPortrait','nameplates','buffs','debuffs','partyRaid','arena','actionBars','other'}
local PROVIDERS = {'weakauras','elvui','threatplates','betterblizzplates','platynator','plater','tellmewhen','shadowed','vuhdo','healbot','grid2','kuinameplates','godmodenameplates','pitbull4','zperl','tperl','arenaaddons','bartender4','dominos','ellesmereui'}
Addon.ForeverCompatibilityProviders = PROVIDERS
Addon.ForeverCompatibilityScopes = SCOPES

local initializedGlobal, initializedCenter
local function ensureCenter()
    local g = Addon.db and Addon.db.global
    if not g then return nil end
    -- Cache normalized provider tables; UI edits mutate the same table live.
    if initializedGlobal == g and initializedCenter and g.compatibilityCenter == initializedCenter then
        return initializedCenter
    end
    g.compatibilityCenter = g.compatibilityCenter or {enabled=true, addons={}}
    local c = g.compatibilityCenter
    if c.enabled == nil then c.enabled = true end
    c.addons = c.addons or {}
    for _,id in ipairs(PROVIDERS) do
        local cfg = c.addons[id]
        if type(cfg) ~= 'table' then cfg={enabled=false,scopes={}}; c.addons[id]=cfg end
        if cfg.enabled == nil then cfg.enabled=false end
        cfg.scopes = type(cfg.scopes)=='table' and cfg.scopes or {}
        -- migrate any old combined aura switch without coupling them afterward
        if cfg.scopes.auras ~= nil then
            if cfg.scopes.buffs == nil then cfg.scopes.buffs = cfg.scopes.auras and true or false end
            if cfg.scopes.debuffs == nil then cfg.scopes.debuffs = cfg.scopes.auras and true or false end
            cfg.scopes.auras = nil
        end
    end
    initializedGlobal, initializedCenter = g, c
    return c
end
function Addon:GetCompatibilityProvider(id)
    local c=ensureCenter(); return c and c.addons[id] or nil
end
function Addon:CompatibilityProviderOwnsScope(provider,scope)
    -- Session-only preset: no changes to saved Compatibility Center choices.
    -- In Cooldowns Only, third-party UI providers retain visual ownership.
    if _G.OmniCC_GODMODE_CooldownsOnly == true then
        return provider == 'threatplates' and (scope == nil or scope == 'nameplates' or scope == 'buffs' or scope == 'debuffs')
    end
    local c=ensureCenter(); if not c or c.enabled==false then return false end
    local cfg=c.addons[provider]
    if type(cfg)~='table' or cfg.enabled~=true then return false end
    if not scope then
        for _,v in pairs(cfg.scopes or {}) do if v==true then return true end end
        return false
    end
    return type(cfg.scopes)=='table' and cfg.scopes[scope]==true
end
function Addon:CompatibilityOwnsScope(scope)
    if _G.OmniCC_GODMODE_CooldownsOnly == true then
        -- Release visual nameplate ownership only. Never release action bars,
        -- target/player cooldowns, or the core countdown engine.
        return scope == 'nameplates' or scope == 'buffs' or scope == 'debuffs'
    end
    local c=ensureCenter(); if not c or c.enabled==false then return false end
    for _,cfg in pairs(c.addons or {}) do
        if type(cfg)=='table' and cfg.enabled==true and type(cfg.scopes)=='table' and cfg.scopes[scope]==true then return true end
    end
    return false
end
function Addon:CompatibilityOwnsAllCooldownAreas()
    for _,scope in ipairs(SCOPES) do if not self:CompatibilityOwnsScope(scope) then return false end end
    return true
end

local function safeName(f)
    if not f or not f.GetName then return '' end
    local ok,n=pcall(f.GetName,f); return ok and type(n)=='string' and n or ''
end
local function ancestry(frame)
    local names, f = {}, frame
    for _=1,16 do
        if not f then break end
        local n=safeName(f); if n~='' then names[#names+1]=n end
        if not f.GetParent then break end
        local ok,p=pcall(f.GetParent,f); if not ok then break end
        f=p
    end
    return table.concat(names,' ')
end
local function has(s,p) return s:find(p,1,true)~=nil end
local function addonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then local ok,v=pcall(C_AddOns.IsAddOnLoaded,name); if ok and v then return true end end
    if IsAddOnLoaded then local ok,v=pcall(IsAddOnLoaded,name); if ok and v then return true end end
    return false
end
local function hasAuraDisplayShape(frame)
    local f=frame
    for _=1,16 do
        if not f then break end
        local ok,b,d,c,pb,pb2,pl=pcall(function()
            return f.BuffDisplay,f.DebuffDisplay,f.CrowdControlDisplay,
                   f.BuffFrame,f.BuffFrame2,f.PlaterBuffList
        end)
        if ok and (b or d or c or pb or pb2 or pl) then return true end
        if not f.GetParent then break end
        local pok,p=pcall(f.GetParent,f); if not pok then break end
        f=p
    end
    return false
end
function Addon:GetCompatibilityScope(frame)
    if not frame then return 'other' end
    if frame._ogmCompatScope then return frame._ogmCompatScope end
    if frame.OGMTargetAuraKind=='BUFF' then frame._ogmCompatScope='buffs'; return 'buffs' end
    if frame.OGMTargetAuraKind=='DEBUFF' then frame._ogmCompatScope='debuffs'; return 'debuffs' end
    if frame.OGMGodmodeNameplateCooldown then frame._ogmCompatScope='nameplates'; return 'nameplates' end
    -- Forever/Midnight third-party nameplate addons can create unnamed aura
    -- children under UIParent before the plate parent is finalized.  Names
    -- alone therefore misfile these cooldowns as `other`.  Platynator and
    -- Threat Plates 13.3 both expose Blizzard-style aura display fields on
    -- an ancestor; classify that shape as nameplates while either provider
    -- is actually loaded.
    -- Plater can also create/recycle unnamed AuraContainer cooldowns whose
    -- ancestry is temporarily just UIParent.  Treat Blizzard-style aura-display
    -- shapes as nameplates while Plater is loaded as well.  This is important
    -- for Compatibility Center -> Plater -> Nameplates: RELEASE must mean a
    -- true release (no GODMODE countdown text or styling on Plater's auras).
    if (addonLoaded('Plater') or addonLoaded('Platynator') or addonLoaded('TidyPlates_ThreatPlates')) and hasAuraDisplayShape(frame) then
        frame._ogmCompatScope='nameplates'
        return 'nameplates'
    end
    local n=ancestry(frame)
    local scope
    if has(n,'TargetFrameBuff') or has(n,'FocusFrameBuff') then scope='buffs'
    elseif has(n,'TargetFrameDebuff') or has(n,'FocusFrameDebuff') then scope='debuffs'
    elseif has(n,'OmniCC_GODMODE_TargetPortrait') or has(n,'TargetPortrait') then scope='targetPortrait'
    elseif has(n,'CompactArenaFrame') or has(n,'ArenaEnemy') or has(n,'Gladius') or has(n,'sArena') or has(n,'ArenaFrame') then scope='arena'
    elseif has(n,'NamePlate') or has(n,'Plater') or has(n,'ThreatPlate') or has(n,'KuiNameplate') or has(n,'ElvUI_NamePlate') then scope='nameplates'
    elseif has(n,'CompactRaidFrame') or has(n,'CompactPartyFrame') or has(n,'Grid2') or has(n,'VuhDo') or has(n,'HealBot') or has(n,'PartyFrame') or has(n,'RaidFrame') then scope='partyRaid'
    elseif has(n,'TargetFrame') or has(n,'FocusFrame') then scope='target'
    elseif has(n,'PlayerFrame') or has(n,'OmniCC_GODMODE_Player') or has(n,'OmniCC_GODMODE_Self') then scope='player'
    elseif has(n,'ActionButton') or has(n,'MultiBar') or has(n,'BT4Button') or has(n,'Bartender') or has(n,'Dominos') or has(n,'ElvUI_Bar') or has(n,'PetActionButton') or has(n,'StanceButton') or has(n,'PossessButton') then scope='actionBars' end
    -- Cache only a positively identified stable scope. Some third-party frames
    -- are temporarily parented under UIParent while being constructed; caching
    -- `other` there would permanently misclassify them after their real parent lands.
    if scope then frame._ogmCompatScope=scope; return scope end
    return 'other'
end
local function ellesmereCompatEnabled()
    local c=ensureCenter(); local cfg=c and c.addons and c.addons.ellesmereui
    return c and c.enabled~=false and type(cfg)=='table' and cfg.enabled==true
end
local function isEllesmereUnitFrameCooldown(frame)
    if not frame or not ellesmereCompatEnabled() then return false end
    local n=ancestry(frame)
    -- Ellesmere AuraKit owns the countdown FontString on both Unit Frame aura
    -- containers and the Player Aura Bars beside the minimap.  Suppress the
    -- generic OmniCC renderer on all of them; GODMODE controls AuraKit's one
    -- existing timer through the bridge below.
    return has(n,'EllesmereUIUnitFrames_')
        or has(n,'EllesmereUIPlayerAuraBars_Buffs')
        or has(n,'EllesmereUIPlayerAuraBars_Debuffs')
end
function Addon:CompatibilityOwnsFrame(frame)
    -- TP's existing aura cooldowns belong to GODMODE's timer engine in
    -- Cooldowns Only; TP retains ownership of their icons and geometry.
    local tp = Addon.ForeverThreatPlatesBridge or Addon.MidnightThreatPlatesBridge
    if _G.OmniCC_GODMODE_CooldownsOnly == true and tp and tp.OwnsCooldown and tp:OwnsCooldown(frame) then return false end
    -- CAMERA HOT-PATH FAST EXIT:
    -- GODMODE-owned nameplate cooldowns are explicitly classified at creation.
    -- Never run Ellesmere/parent ancestry discovery for them on every SetCooldown.
    if frame and (frame.OGMGodmodeNameplateCooldown or frame.OGMNameplateAura or frame.OGMNameplateBoundDuration or frame._ogmCompatScope == 'nameplates') then
        return self:CompatibilityOwnsScope('nameplates')
    end
    -- Ellesmere AuraKit already owns the secure duration binding.  Never let the
    -- generic OmniCC engine add a second number on top of it.  When an area is
    -- UNCHECKED, GODMODE drives AuraKit's own text/settings through the bridge;
    -- when CHECKED, Ellesmere's saved settings are restored.  Either way there
    -- must be exactly one renderer on Ellesmere unit-frame aura buttons.
    if isEllesmereUnitFrameCooldown(frame) then return true end
    return self:CompatibilityOwnsScope(self:GetCompatibilityScope(frame))
end
function Addon:GodmodeHardOwnsFrame(frame)
    return not self:CompatibilityOwnsScope(self:GetCompatibilityScope(frame))
end

local function reclaimKnownCooldowns()
    -- Event-driven/known cooldowns only: no UIParent full-tree scan.
    local list={}
    for i=1,180 do
        local b=_G['ActionButton'..i] or _G['MultiBarBottomLeftButton'..i] or _G['MultiBarBottomRightButton'..i] or _G['MultiBarRightButton'..i] or _G['MultiBarLeftButton'..i]
        if b then list[#list+1]=b.Cooldown or b.cooldown end
    end
    for i=1,64 do
        local b=_G['TargetFrameBuff'..i]; if b then list[#list+1]=b.Cooldown or b.cooldown end
        local d=_G['TargetFrameDebuff'..i]; if d then list[#list+1]=d.Cooldown or d.cooldown end
        local fb=_G['FocusFrameBuff'..i]; if fb then list[#list+1]=fb.Cooldown or fb.cooldown end
        local fd=_G['FocusFrameDebuff'..i]; if fd then list[#list+1]=fd.Cooldown or fd.cooldown end
    end
    for _,cd in ipairs(list) do
        if cd and Addon:GodmodeHardOwnsFrame(cd) then
            cd.noCooldownCount=nil
            if cd.SetHideCountdownNumbers and not cd.OGMTargetAuraNativeSuppressed then
                pcall(cd.SetHideCountdownNumbers,cd,false)
            end
        end
    end
end

-- Ellesmere Player Aura Bars use AuraKit's own secure duration renderer.
-- When Ellesmere compatibility is enabled but the Player scope is UNCHECKED,
-- GODMODE owns that area: turn AuraKit Duration OFF so its number cannot stack
-- with GODMODE.  Restore the exact previous values when Player is released.
local function syncEllesmerePlayerAuraBarDurations()
    if not ellesmereCompatEnabled() then return end
    local EUI=_G.EllesmereUI
    local ns=EUI and EUI._ModuleNS and EUI._ModuleNS['EllesmereUIUnitFrames']
    local prof=ns and ns.db and ns.db.profile
    local pab=prof and prof.playerAuraBars
    if not (ns and pab) then return end
    local godmodeOwnsPlayer = not Addon:CompatibilityProviderOwnsScope('ellesmereui','player')
    local g=Addon.db and Addon.db.global
    if not g then return end
    g.ellesmerePABDurationOriginal = g.ellesmerePABDurationOriginal or {}
    local saved=g.ellesmerePABDurationOriginal
    local at=Addon.ForeverAuraText
    local buffIcon=(at and at.GetScopedIconSize and at:GetScopedIconSize('PLAYER','BUFF')) or 16
    local debuffIcon=(at and at.GetScopedIconSize and at:GetScopedIconSize('PLAYER','DEBUFF')) or 16
    -- Player Aura Bars beside the minimap deliberately stay larger than unit-frame auras.
    -- Use the same 2x-2 rule as Blizzard BuffFrame: 16 -> 30, 20 -> 38.
    local pabBuffIcon=(at and at.GetExternalIconSize and at:GetExternalIconSize('BUFF')) or (buffIcon*2-2)
    local pabDebuffIcon=(at and at.GetExternalIconSize and at:GetExternalIconSize('DEBUFF')) or (debuffIcon*2-2)
    local buffText=(at and at.GetScopedTextSize and at:GetScopedTextSize('PLAYER','BUFF')) or 12
    local debuffText=(at and at.GetScopedTextSize and at:GetScopedTextSize('PLAYER','DEBUFF')) or 12
    local touched=false
    -- Keep the visual anchor stable while icon size changes. Ellesmere's PAB
    -- layout may otherwise reflow the row toward the opposite screen edge.
    -- We do not change its configured growth direction/position here.
    local function own(key,cfg,isBuff)
        if type(cfg)~='table' then return end
        if godmodeOwnsPlayer then
            if saved[key]==nil then
                saved[key]={
                    durationShow=cfg.durationShow,
                    durationTextSize=cfg.durationTextSize,
                    iconSize=cfg.iconSize,
                }
            end
            -- Ellesmere owns the secure AuraKit FontString on Player Aura Bars.
            -- GODMODE controls that EXISTING timer instead of hiding it and trying
            -- to create a second timer. Generic OmniCC is already suppressed on
            -- Ellesmere AuraKit cooldown frames by CompatibilityOwnsFrame().
            local wantIcon=isBuff and pabBuffIcon or pabDebuffIcon
            local wantText=isBuff and buffText or debuffText
            if cfg.durationShow~=true then cfg.durationShow=true; touched=true end
            if cfg.durationTextSize~=wantText then cfg.durationTextSize=wantText; touched=true end
            if cfg.iconSize~=wantIcon then cfg.iconSize=wantIcon; touched=true end
        elseif saved[key]~=nil then
            local o=saved[key]
            -- Migrate pre-1.3.4 bridge state (0/1 duration-only snapshots) safely.
            -- Never index legacy numeric SavedVariables as a table.
            if type(o)=='table' then
                if cfg.durationShow~=o.durationShow then cfg.durationShow=o.durationShow; touched=true end
                if o.durationTextSize~=nil and cfg.durationTextSize~=o.durationTextSize then cfg.durationTextSize=o.durationTextSize; touched=true end
                if o.iconSize~=nil and cfg.iconSize~=o.iconSize then cfg.iconSize=o.iconSize; touched=true end
            elseif type(o)=='number' then
                local want=o==1
                if cfg.durationShow~=want then cfg.durationShow=want; touched=true end
            end
            saved[key]=nil
        end
    end
    if ns.PAB_DefaultBuffsCfg then local ok,cfg=pcall(ns.PAB_DefaultBuffsCfg,pab); if ok then own('buffs',cfg,true) end end
    if ns.PAB_DefaultDebuffsCfg then local ok,cfg=pcall(ns.PAB_DefaultDebuffsCfg,pab); if ok then own('debuffs',cfg,false) end end
    if ns.PAB_CustomBuffBars then local ok,t=pcall(ns.PAB_CustomBuffBars); if ok and type(t)=='table' then for i,cfg in ipairs(t) do own('customBuff'..i,cfg,true) end end end
    if ns.PAB_CustomDebuffBars then local ok,t=pcall(ns.PAB_CustomDebuffBars); if ok and type(t)=='table' then for i,cfg in ipairs(t) do own('customDebuff'..i,cfg,false) end end end
    -- YOUR BUFFS / DEBUFFS also owns the actual Ellesmere PLAYER unit-frame
    -- aura row (the icons attached to your self frame), not only Player Aura Bars.
    -- Write the same values to the real Unit Frames profile and AuraKit styles.
    local player=prof and prof.player
    if godmodeOwnsPlayer and type(player)=='table' then
        -- Mirror the four GODMODE frame-aura switches into Ellesmere's actual
        -- player Unit Frame.  Ellesmere uses showBuffs for helpful auras and
        -- debuffAnchor='none' to disable harmful auras, so keep its original
        -- anchor and restore it when GODMODE Debuffs is turned back ON.
        local selfBuffOn = not at or not at.GetFrameAuraEnabled or at:GetFrameAuraEnabled('SELF','BUFF')
        local selfDebuffOn = not at or not at.GetFrameAuraEnabled or at:GetFrameAuraEnabled('SELF','DEBUFF')
        local buffTextOn = not at or not at.GetFrameCountdownTextEnabled or at:GetFrameCountdownTextEnabled('BUFF')
        local debuffTextOn = not at or not at.GetFrameCountdownTextEnabled or at:GetFrameCountdownTextEnabled('DEBUFF')
        g.ellesmerePlayerAuraOriginal = g.ellesmerePlayerAuraOriginal or {
            showBuffs=player.showBuffs, debuffAnchor=player.debuffAnchor, simpleDebuffs=player.simpleDebuffs,
        }
        local po=g.ellesmerePlayerAuraOriginal
        -- Ellesmere's Simple Debuff mode forces debuff icons to frame-height and
        -- bypasses debuffSize. While GODMODE owns the controls, use the normal
        -- Ellesmere debuff lane so our Debuff Icon +/- can actually control it.
        player.simpleDebuffs='none'
        player.showBuffs = selfBuffOn and true or false
        if selfDebuffOn then
            if player.debuffAnchor=='none' then player.debuffAnchor=(po.debuffAnchor and po.debuffAnchor~='none') and po.debuffAnchor or 'bottomleft' end
        else
            if player.debuffAnchor and player.debuffAnchor~='none' then po.debuffAnchor=player.debuffAnchor end
            player.debuffAnchor='none'
        end
        player.buffSize=buffIcon; player.debuffSize=debuffIcon
        player.buffShowCooldownText=buffTextOn and true or false; player.debuffShowCooldownText=debuffTextOn and true or false
        player.buffCooldownTextSize=buffText; player.debuffCooldownTextSize=debuffText

        -- TARGET must use Ellesmere's own Unit Frames options/profile too. Do not
        -- create/re-anchor a competing GODMODE row while Ellesmere owns the frame.
        local target=prof and prof.target
        if type(target)=='table' then
            local targetBuffOn = not at or not at.GetFrameAuraEnabled or at:GetFrameAuraEnabled('TARGET','BUFF')
            local targetDebuffOn = not at or not at.GetFrameAuraEnabled or at:GetFrameAuraEnabled('TARGET','DEBUFF')
            g.ellesmereTargetAuraOriginal = g.ellesmereTargetAuraOriginal or {
                showBuffs=target.showBuffs, buffAnchor=target.buffAnchor, debuffAnchor=target.debuffAnchor, simpleDebuffs=target.simpleDebuffs,
            }
            local to=g.ellesmereTargetAuraOriginal
            -- Same rule on Target: Simple Debuffs ignores debuffSize, so switch
            -- to Ellesmere's normal debuff lane while GODMODE owns sizing.
            target.simpleDebuffs='none'
            target.showBuffs=targetBuffOn and true or false
            if targetBuffOn and target.buffAnchor=='none' then target.buffAnchor=(to.buffAnchor and to.buffAnchor~='none') and to.buffAnchor or 'topleft' end
            if targetDebuffOn then
                if target.debuffAnchor=='none' then target.debuffAnchor=(to.debuffAnchor and to.debuffAnchor~='none') and to.debuffAnchor or 'bottomleft' end
            else
                if target.debuffAnchor and target.debuffAnchor~='none' then to.debuffAnchor=target.debuffAnchor end
                target.debuffAnchor='none'
            end
            target.buffSize=buffIcon; target.debuffSize=debuffIcon
            target.buffShowCooldownText=buffTextOn and true or false; target.debuffShowCooldownText=debuffTextOn and true or false
            target.buffCooldownTextSize=buffText; target.debuffCooldownTextSize=debuffText
        end
        local AK=EUI and EUI.AuraKit
        if AK and type(AK.styles)=='table' then
            for skey,st in pairs(AK.styles) do
                if type(skey)=='string' and type(st)=='table' then
                    if skey:find('uf:player:HELPFUL',1,true)==1 then
                        local pnt=at and at.GetFrameCountdownTextAnchor and at:GetFrameCountdownTextAnchor('BUFF') or 'BOTTOM'; local tx,ty=0,0; if at and at.GetFrameCountdownTextOffset then tx,ty=at:GetFrameCountdownTextOffset('BUFF') end; st.width=buffIcon; st.height=buffIcon; st.cdTextSize=math.max(1,tonumber(buffText) or 12); st.showCooldownText=buffTextOn; st.cdTextPoint=pnt; st.cdTextAnchor=pnt; st.cdTextX=tx; st.cdTextY=ty
                        if AK.RestyleSoon then pcall(AK.RestyleSoon,skey) end
                    elseif skey:find('uf:player:HARMFUL',1,true)==1 then
                        local pnt=at and at.GetFrameCountdownTextAnchor and at:GetFrameCountdownTextAnchor('DEBUFF') or 'BOTTOM'; local tx,ty=0,0; if at and at.GetFrameCountdownTextOffset then tx,ty=at:GetFrameCountdownTextOffset('DEBUFF') end; st.width=debuffIcon; st.height=debuffIcon; st.cdTextSize=math.max(1,tonumber(debuffText) or 12); st.showCooldownText=debuffTextOn; st.cdTextPoint=pnt; st.cdTextAnchor=pnt; st.cdTextX=tx; st.cdTextY=ty
                        if AK.RestyleSoon then pcall(AK.RestyleSoon,skey) end
                    end
                end
            end
        end
        -- Apply SELF/TARGET through Ellesmere's own reload path so its own anchor,
        -- growth, spacing and row logic remain authoritative. One deferred reload
        -- collapses rapid +/- clicks and avoids fighting AuraKit's layout engine.
        -- Do not rebuild Ellesmere Player/Target unit frames from GODMODE aura controls.
        -- AuraKit RestyleSoon below is sufficient and avoids repeated secure-frame rebuilds.
    end
    if touched then
        -- Player Aura Bars have their own live apply path.  Do NOT call
        -- _EUF_ReloadFrames here: that rebuilds Player/Target unit frames and is
        -- the visible 'jump' seen when a GODMODE size control is clicked.
        if ns.PAB_Restyle then pcall(ns.PAB_Restyle) end
        if ns.PAB_ApplyLiveConfig then
            pcall(ns.PAB_ApplyLiveConfig,true)
            pcall(ns.PAB_ApplyLiveConfig,false)
        elseif ns.PAB_Apply then
            pcall(ns.PAB_Apply)
        end
    end
end

-- Ellesmere builds AuraKit style tables with its Unit Frames font.  Do not alter
-- Ellesmere's global font setting: when GODMODE owns the scope, override only
-- the AuraKit duration styles with GODMODE's selected font.  Releasing the scope
-- restores the exact Ellesmere style font path.  This is deliberately isolated
-- from every other compatibility provider.
local euiStyleFontOriginal={}
local function syncEllesmereAuraFonts()
    if not ellesmereCompatEnabled() then return end
    local EUI=_G.EllesmereUI
    local AK=EUI and EUI.AuraKit
    if not (AK and type(AK.styles)=='table') then return end
    local LSM=LibStub and LibStub('LibSharedMedia-3.0',true)
    local profile=Addon.db and Addon.db.profile
    local themes=profile and profile.themes
    local function fontFor(kind)
        local th=themes and themes[kind=='BUFF' and 'godmode_nameplate_buffs' or kind=='DEBUFF' and 'godmode_nameplate_debuffs' or 'default']
        if not th then th=themes and themes.default end
        return (th and th.font and LSM and LSM:Fetch('font',th.font)) or STANDARD_TEXT_FONT
    end
    local ownsPlayer=not Addon:CompatibilityProviderOwnsScope('ellesmereui','player')
    local ownsBuff=not Addon:CompatibilityProviderOwnsScope('ellesmereui','buffs')
    local ownsDebuff=not Addon:CompatibilityProviderOwnsScope('ellesmereui','debuffs')
    local function apply(key,st,own,font)
        if type(st)~='table' then return end
        if own then
            if euiStyleFontOriginal[key]==nil then euiStyleFontOriginal[key]=st.fontPath or false end
            if st.fontPath~=font then st.fontPath=font; if AK.RestyleSoon then pcall(AK.RestyleSoon,key) end end
        elseif euiStyleFontOriginal[key]~=nil then
            local old=euiStyleFontOriginal[key]; if old==false then old=nil end
            if st.fontPath~=old then st.fontPath=old; if AK.RestyleSoon then pcall(AK.RestyleSoon,key) end end
            euiStyleFontOriginal[key]=nil
        end
    end
    -- Include AuraKit's derived style variants, not only the base key.
    for key,st in pairs(AK.styles) do
        if type(key)=='string' then
            if key:find('uf:target:HELPFUL',1,true)==1 then apply(key,st,ownsBuff,fontFor('BUFF'))
            elseif key:find('uf:target:HARMFUL',1,true)==1 then apply(key,st,ownsDebuff,fontFor('DEBUFF'))
            elseif key:find('uf:player:HELPFUL',1,true)==1 or key:find('uf:player:HARMFUL',1,true)==1
                or key:find('playerAuraBars_buffs',1,true)==1 or key:find('playerAuraBars_debuffs',1,true)==1 then
                apply(key,st,ownsPlayer,fontFor('PLAYER'))
            end
        end
    end
end
Addon.SyncEllesmereAuraFonts = syncEllesmereAuraFonts

-- Public live bridge used by the right-click/Buffs-Debuffs controls.  Without
-- this, changing GODMODE values only rebuilt GODMODE's own rows and Ellesmere
-- kept its previous AuraKit sizes/text until a compatibility refresh/reload.
function Addon:SyncEllesmereAuraControls()
    syncEllesmerePlayerAuraBarDurations()
    syncEllesmereAuraFonts()
end

-- Plater Forever ownership bridge ------------------------------------------------
-- Plater 1.60.1 does not merely expose passive aura frames: when
-- profile.aura_enabled is true its UNIT_AURA path repopulates BuffFrame/BuffFrame2
-- and can Show() them again after another addon hides them.  Therefore GODMODE
-- ownership must disable Plater's aura PRODUCER, not chase recycled icon frames.
-- We preserve the user's exact Plater setting and restore it whenever Plater owns
-- the scope or Compatibility is disabled.
local platerAuraBridge = { active=false, original=nil }
local function syncPlaterNameplateAuraOwnership()
    local P=_G.Plater
    local prof=P and P.db and P.db.profile
    if not prof or prof.aura_enabled==nil then return end

    local center=ensureCenter()
    local cfg=center and center.addons and center.addons.plater
    local compatActive=center and center.enabled~=false and type(cfg)=='table' and cfg.enabled==true
    local platerOwns=compatActive and type(cfg.scopes)=='table' and cfg.scopes.nameplates==true
    local godmodeOwns=compatActive and not platerOwns

    -- Snapshot Plater's setting once for the whole compatibility session.  Older
    -- GODMODE builds could leave aura_enabled=false behind; when the user explicitly
    -- checks Plater -> Nameplates we must still turn Plater's aura provider ON.
    if compatActive and not platerAuraBridge.active then
        platerAuraBridge.original = prof.aura_enabled and true or false
        platerAuraBridge.active = true
    end

    local desired
    if compatActive then
        -- CHECKED = Plater owns the scope, so its provider must be enabled.
        -- UNCHECKED = GODMODE owns the scope, so Plater's provider must be disabled.
        desired = platerOwns and true or false
    elseif platerAuraBridge.active then
        -- Master compatibility OFF (or Plater compatibility OFF): restore exactly
        -- what the user had before entering the compatibility session.
        desired = platerAuraBridge.original
        platerAuraBridge.active = false
        platerAuraBridge.original = nil
    else
        return
    end

    if prof.aura_enabled ~= desired then prof.aura_enabled=desired end
    -- This is the same public refresh sequence used by Plater's own aura_enabled
    -- option. It updates Plater_Auras.lua's DB_AURA_ENABLED upvalue, then rebuilds
    -- visible plates. Do not touch any other Plater profile option.
    if P.RefreshDBUpvalues then pcall(P.RefreshDBUpvalues) end
    if P.UpdateAllPlates then pcall(P.UpdateAllPlates) end
    -- Plater may apply its profile/upvalues one frame after the Compatibility
    -- checkbox callback. Reassert the selected provider once after that handoff
    -- so CHECKED Nameplates visibly returns the aura row immediately.
    if platerOwns and C_Timer and C_Timer.After then
        C_Timer.After(0.10,function()
            local PP=_G.Plater
            local pp=PP and PP.db and PP.db.profile
            if pp and pp.aura_enabled~=nil then
                pp.aura_enabled=true
                if PP.RefreshDBUpvalues then pcall(PP.RefreshDBUpvalues) end
                if PP.UpdateAllPlates then pcall(PP.UpdateAllPlates) end
            end
        end)
    end

    -- Old/Forever Plater keeps pooled BuffFrame/BuffFrame2 icons. Hide them
    -- immediately when GODMODE owns the scope; the producer is already disabled
    -- above, so UNIT_AURA cannot repopulate them afterward.
    if godmodeOwns and P.GetAllShownPlates then
        local ok,plates=pcall(P.GetAllShownPlates)
        if ok and type(plates)=='table' then
            for _,plate in ipairs(plates) do
                local uf=plate and plate.unitFrame
                for _,row in ipairs({uf and uf.BuffFrame,uf and uf.BuffFrame2}) do
                    if row then
                        local list=row.PlaterBuffList
                        if type(list)=='table' then
                            for _,icon in ipairs(list) do if icon and icon.Hide then pcall(icon.Hide,icon) end end
                        end
                        if row.Hide then pcall(row.Hide,row) end
                    end
                end
            end
        end
    end
end

-- Ellesmere NPC nameplate aura ownership bridge ---------------------------------
-- EllesmereUINameplates owns three AuraKit containers (buffs/debuffs/cc) per
-- plate. Merely suspending GODMODE leaves those producers alive, which creates
-- duplicate icons/text. Transfer the producer itself in both directions.
local euiNPBridgeHooked=false
local function syncEllesmereNameplateAuraOwnership()
    if not ellesmereCompatEnabled() then return end
    local EUI=_G.EllesmereUI
    local ns=EUI and EUI._ModuleNS and EUI._ModuleNS['EllesmereUINameplates']
    if not ns then return end
    local ellesmereOwns=Addon:CompatibilityProviderOwnsScope('ellesmereui','nameplates')
    local plates=(C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}

    if not euiNPBridgeHooked and type(ns.NPC_AttachPlate)=='function' and hooksecurefunc then
        euiNPBridgeHooked=true
        hooksecurefunc(ns,'NPC_AttachPlate',function(plate)
            if not Addon:CompatibilityProviderOwnsScope('ellesmereui','nameplates') and ns.NPC_DetachPlate then
                pcall(ns.NPC_DetachPlate,plate)
            end
        end)
    end

    if ellesmereOwns then
        -- Re-attach/reload Ellesmere immediately for plates that already exist.
        if ns.NPC_AttachPlate then
            for _,plate in ipairs(plates) do
                local unit=plate and plate.namePlateUnitToken
                if not unit and plate and plate.UnitFrame then unit=plate.UnitFrame.unit end
                if unit then pcall(ns.NPC_AttachPlate,plate,unit) end
            end
        end
        if ns.NPC_ReloadAll then pcall(ns.NPC_ReloadAll) end
    else
        -- GODMODE owns this scope: park Ellesmere's complete aura bundles.
        if ns.NPC_DetachPlate then
            for _,plate in ipairs(plates) do pcall(ns.NPC_DetachPlate,plate) end
        end
    end
end

-- Read-only bridge. TPerl styles its secure DurationText; GODMODE does not
-- create a second countdown on adopted aura buttons.
_G.OmniCC_GODMODE_GetTPerlAuraTheme = function()
    local profile = Addon.db and Addon.db.profile
    local t = profile and profile.themes and profile.themes.auras
    if type(t) ~= 'table' then return nil end
    local fontPath
    if t.font then
        local media = LibStub and LibStub('LibSharedMedia-3.0', true)
        fontPath = media and media:Fetch('font', t.font) or nil
    end
    return {fontPath=fontPath, fontSize=t.fontSize, fontFlags=t.fontFlags,
        point=t.point, offsetX=t.offsetX, offsetY=t.offsetY,
        defaultTextColor=t.defaultTextColor}
end

local function syncTPerlDurationOwnership()
    local api = _G.TPerl_GODMODE_SetDurationOwnership
    if type(api) ~= 'function' then return end
    local center = ensureCenter()
    local cfg = center and center.addons and center.addons.tperl
    local active = center and center.enabled ~= false and type(cfg) == 'table' and cfg.enabled == true
    local scopes = active and cfg.scopes or nil
    -- Unchecked scopes are GODMODE-owned; checked scopes remain TPerl-owned.
    -- This never alters TPerl settings or its renderer when TPerl owns a scope.
    local buffs = active and not (scopes and scopes.buffs == true)
    local debuffs = active and not (scopes and scopes.debuffs == true)
    pcall(api, buffs == true, debuffs == true)
end

local function refreshModules()
    syncTPerlDurationOwnership()
    syncPlaterNameplateAuraOwnership()
    syncEllesmereNameplateAuraOwnership()
    syncEllesmerePlayerAuraBarDurations()
    syncEllesmereAuraFonts()
    local player=Addon:CompatibilityOwnsScope('player')
    local target=Addon:CompatibilityOwnsScope('target')
    local portrait=Addon:CompatibilityOwnsScope('targetPortrait')
    local np=Addon:CompatibilityOwnsScope('nameplates')
    local buffs=Addon:CompatibilityOwnsScope('buffs')
    local debuffs=Addon:CompatibilityOwnsScope('debuffs')
    if Addon.ForeverNameplates then
        Addon.ForeverNameplates._compatSuspended=np
        if Addon.ForeverNameplates.Refresh then pcall(Addon.ForeverNameplates.Refresh) end
    end
    if Addon.ForeverOwnedNameplateDebuffs then
        Addon.ForeverOwnedNameplateDebuffs._compatSuspended=np
        if Addon.ForeverOwnedNameplateDebuffs.RefreshAll then pcall(Addon.ForeverOwnedNameplateDebuffs.RefreshAll,Addon.ForeverOwnedNameplateDebuffs) end
    end
    if Addon.ForeverSelfCooldowns then
        Addon.ForeverSelfCooldowns._compatSuspended=player
        if Addon.ForeverSelfCooldowns.Refresh then pcall(Addon.ForeverSelfCooldowns.Refresh,Addon.ForeverSelfCooldowns) end
    end
    if Addon.ForeverPlayerCC then
        Addon.ForeverPlayerCC._compatSuspended=player
        if Addon.ForeverPlayerCC.Refresh then pcall(Addon.ForeverPlayerCC.Refresh,Addon.ForeverPlayerCC) end
    end
    if Addon.ForeverTargetPortrait then
        Addon.ForeverTargetPortrait._compatSuspended=target
        Addon.ForeverTargetPortrait._compatTimerSuspended=(target or portrait)
        if Addon.ForeverTargetPortrait.Refresh then pcall(Addon.ForeverTargetPortrait.Refresh,Addon.ForeverTargetPortrait) end
    end
    if Addon.ForeverTargetAuraTimers and Addon.ForeverTargetAuraTimers.SetCompatibilityScopes then
        pcall(Addon.ForeverTargetAuraTimers.SetCompatibilityScopes,buffs,debuffs)
    end
    -- Threat Plates 13.3 Forever uses its own Blizzard AuraContainers.  The
    -- provider bridge must enforce the same CHECKED=external / UNCHECKED=GODMODE
    -- ownership contract immediately when the Compatibility Center changes.
    if Addon.ForeverThreatPlatesBridge and Addon.ForeverThreatPlatesBridge.Refresh then
        pcall(Addon.ForeverThreatPlatesBridge.Refresh,Addon.ForeverThreatPlatesBridge)
    end
end
function Addon:RefreshCompatibilityOwnership()
    ensureCenter(); reclaimKnownCooldowns(); refreshModules(); self:Refresh()
end
function Addon:HardSyncCompatibilityOwnership() self:RefreshCompatibilityOwnership() end
function Addon:QueueCompatibilityHardSync()
    self:RefreshCompatibilityOwnership()
    if C_Timer and C_Timer.After then
        C_Timer.After(.20,function() if Addon.db then Addon:RefreshCompatibilityOwnership() end end)
        C_Timer.After(.80,function() if Addon.db then Addon:RefreshCompatibilityOwnership() end end)
    end
end
local e=CreateFrame('Frame')
e:RegisterEvent('PLAYER_ENTERING_WORLD'); e:RegisterEvent('ADDON_LOADED')
e:SetScript('OnEvent',function(_,event,name)
    if event=='ADDON_LOADED' and name==AddonName then return end
    if Addon.db then Addon:QueueCompatibilityHardSync() end
end)
