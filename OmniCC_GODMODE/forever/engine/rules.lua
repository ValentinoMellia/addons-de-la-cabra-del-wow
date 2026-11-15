local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

--------------------------------------------------------------------------------
-- Built-in Rules
-- Rules categorize cooldowns; themes are assigned via profile settings
--------------------------------------------------------------------------------

-- Action Buttons
-- TODO: will likely provide a way to combine handlers like these into a single function call for perf
Addon:RegisterRule {
    id = "action",
    priority = 100,
    match = function(cooldown)
        local parent = cooldown:GetParent()
        return parent and parent.action and parent.cooldown == cooldown
    end
}

Addon:RegisterRule {
    id = "action_charge",
    priority = 110,
    match = function(cooldown)
        local parent = cooldown:GetParent()
        return parent and parent.action and parent.chargeCooldown == cooldown
    end
}

Addon:RegisterRule {
    id = "action_loc",
    priority = 120,
    match = function(cooldown)
        local parent = cooldown:GetParent()
        return parent and parent.action and parent.lossOfControlCooldown == cooldown
    end
}

--------------------------------------------------------------------------------
-- Blizzard Cooldown Manager
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
    -- cooldown manager
    Addon:RegisterRule {
        id = "blizzard_cdm_essential",
        priority = 200,
        displayName = strjoin(' - ', COOLDOWN_VIEWER_LABEL, HUD_EDIT_MODE_SYSTEM_ESSENTIAL_COOLDOWNS),
        match = { "^EssentialCooldownViewer" }
    }

    Addon:RegisterRule {
        id = "blizzard_cdm_utility",
        priority = 210,
        displayName = strjoin(' - ', COOLDOWN_VIEWER_LABEL, HUD_EDIT_MODE_SYSTEM_UTILITY_COOLDOWNS),
        match = { "^UtilityCooldownViewer" }
    }

    Addon:RegisterRule {
        id = "blizzard_cdm_buff_icons",
        priority = 220,
        displayName = strjoin(' - ', COOLDOWN_VIEWER_LABEL, HUD_EDIT_MODE_SYSTEM_TRACKED_BUFFS),
        match = { "^BuffIconCooldownViewer" }
    }

    Addon:RegisterRule {
        id = "blizzard_cdm_buff_bars",
        priority = 230,
        displayName = strjoin(' - ', COOLDOWN_VIEWER_LABEL, HUD_EDIT_MODE_SYSTEM_TRACKED_BUFF_BARS),
        match = { "^BuffBarCooldownViewer" }
    }
end)

--------------------------------------------------------------------------------
-- Secondary Bars
--------------------------------------------------------------------------------

-- Pet Action Bar
Addon:RegisterRule {
    id = "blizzard_petbar",
    priority = 300,
    match = { "^PetActionButton%d+" }
}

-- Stance/Shapeshift Bar
Addon:RegisterRule {
    id = "blizzard_stancebar",
    priority = 310,
    match = { "^StanceButton%d+" }
}

-- Possess Bar
Addon:RegisterRule {
    id = "blizzard_possessbar",
    priority = 320,
    match = { "^PossessButton%d+" }
}

-- Extra Action Button
Addon:RegisterRule {
    id = "blizzard_extrabar",
    priority = 330,
    match = { "^ExtraActionButton%d+" }
}

-- Zone Ability Button
Addon:RegisterRule {
    id = "blizzard_zone",
    priority = 340,
    match = { "^ZoneAbilityFrame" }
}

--------------------------------------------------------------------------------
-- Unit Frames
--------------------------------------------------------------------------------

-- GODMODE Forever custom aura rows intentionally use the SAME Nameplates theme
-- as Blizzard nameplates.  Do not split them into hidden buff/debuff themes: the
-- Themes -> Nameplates panel is the single source of truth for every nameplate
-- cooldown, including newly-created custom aura icons.

local function matchMarkedNameplateAura(cooldown)
    local region = cooldown
    local depth = 0
    while region and depth < 12 do
        local okMarker, marker = pcall(function() return region.OGMNameplateAura end)
        if okMarker and marker then return true end
        if not region.GetParent then break end
        local okParent, parent = pcall(region.GetParent, region)
        if not okParent then break end
        region = parent
        depth = depth + 1
    end
    return false
end

Addon:RegisterRule {
    id = "godmode_nameplate_aura",
    priority = 390,
    match = matchMarkedNameplateAura
}

Addon:RegisterRule {
    id = "blizzard_nameplates",
    priority = 400,
    match = { "^NamePlate%d+" }
}

Addon:RegisterRule {
    id = "blizzard_party",
    priority = 410,
    match = { "^PartyFrame", "^CompactPartyFrame" }
}

Addon:RegisterRule {
    id = "blizzard_raid",
    priority = 420,
    match = { "^CompactRaidGroup" }
}

Addon:RegisterRule {
    id = "blizzard_arena",
    priority = 430,
    match = { "^CompactArenaFrame" }
}

Addon:RegisterRule {
    id = "godmode_player_frame",
    priority = 435,
    displayName = "Player Frame",
    -- GODMODE's secure Player AuraContainer duration text consumes this rule
    -- directly during initializeFrame. Marker match keeps the rule visible here
    -- without stealing unrelated Blizzard cooldowns.
    match = { "^OmniCC_GODMODE_PlayerFrameAura" }
}

Addon:RegisterRule {
    id = "blizzard_target",
    priority = 440,
    match = { "^TargetFrame" }
}

Addon:RegisterRule {
    id = "blizzard_focus",
    priority = 450,
    match = { "^FocusFrame" }
}

Addon:RegisterRule {
    id = "blizzard_pet",
    priority = 460,
    match = { "^PetFrame" }
}

--------------------------------------------------------------------------------
-- Encounter Stuff
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterTimeline", function()
    Addon:RegisterRule {
        id = "blizzard_encounter_timeline",
        priority = 500,
        displayName = HUD_EDIT_MODE_SYSTEM_ENCOUNTER_TIMELINE,
        match = { "^EncounterTimeline" }
    }
end)

--------------------------------------------------------------------------------
-- Other Stuff
--------------------------------------------------------------------------------

-- Items
Addon:RegisterRule {
    id = "blizzard_container",
    priority = 600,
    match = { "^ContainerFrame", "^PaperDoll" }
}

--------------------------------------------------------------------------------
-- Addons
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded('ArcUI', function()
    Addon:RegisterRule {
        id = "arcui",
        displayName = C_AddOns.GetAddOnMetadata("ArcUI", "Title"),
        priority = 710,
        match = { "^CDMGroups" }
    }
end)

EventUtil.ContinueOnAddOnLoaded('Grid2', function()
    Addon:RegisterRule {
        id = "grid2",
        displayName = C_AddOns.GetAddOnMetadata("Grid2", "Title"),
        priority = 720,
        match = { "^Grid2Layout" }
    }
end)

--------------------------------------------------------------------------------
-- ...And the rest!
--------------------------------------------------------------------------------

Addon:RegisterRule {
    id = "everything",
    enabled = true,
    priority = math.huge,
    match = function() return true end
}
