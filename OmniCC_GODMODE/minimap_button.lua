local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface == 16001 then return end
local AddonName, Addon = ...

local ICON = 'Interface/Icons/spell_nature_timestop'
local DEFAULT_ANGLE = 150

local button
local db

local function GetDB()
    -- This table is already declared in the Midnight TOC and is therefore
    -- persisted by WoW. Never use an undeclared global for minimap settings.
    OmniCC_GODMODE_MidnightNameplatesDB = OmniCC_GODMODE_MidnightNameplatesDB or {}
    db = OmniCC_GODMODE_MidnightNameplatesDB
    -- v2 default: move GODMODE from 12 o'clock (90°) to about 10 o'clock (150°).
    -- Migrate only the previous exact default; any manually dragged position is preserved.
    if db.minimapDefaultAngleV2 ~= true then
        if type(db.minimapAngle) ~= 'number' or db.minimapAngle == 90 then
            db.minimapAngle = DEFAULT_ANGLE
        end
        db.minimapDefaultAngleV2 = true
    elseif type(db.minimapAngle) ~= 'number' then
        db.minimapAngle = DEFAULT_ANGLE
    end
    if type(db.minimapHidden) ~= 'boolean' then db.minimapHidden = false end
    return db
end

-- Keep the button a real minimap child so minimap managers can discover it.
-- Follow the minimap's current geometry instead of a hard-coded circular radius.
local function GetMinimapShape()
    if type(_G.GetMinimapShape) == 'function' then
        local ok, shape = pcall(_G.GetMinimapShape)
        if ok and type(shape) == 'string' then return shape end
    end
    return 'ROUND'
end

local quadrant = {
    TOPRIGHT = 1, BOTTOMRIGHT = 2, BOTTOMLEFT = 3, TOPLEFT = 4,
}
local function UpdatePosition()
    if not button or not Minimap or not db then return end
    local angle = math.rad(db.minimapAngle or DEFAULT_ANGLE)
    local x, y = math.cos(angle), math.sin(angle)
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    if not w or not h or w <= 0 or h <= 0 then return end
    local halfW, halfH = w * 0.5, h * 0.5
    local shape = GetMinimapShape()
    local q = (x >= 0 and (y >= 0 and 1 or 2)) or (y < 0 and 3 or 4)
    local square = shape == 'SQUARE' or shape == 'RECTANGLE'
        or (shape == 'CORNER-TOPRIGHT' and q ~= 1)
        or (shape == 'CORNER-BOTTOMRIGHT' and q ~= 2)
        or (shape == 'CORNER-BOTTOMLEFT' and q ~= 3)
        or (shape == 'CORNER-TOPLEFT' and q ~= 4)
        or (shape == 'SIDE-RIGHT' and (q == 3 or q == 4))
        or (shape == 'SIDE-LEFT' and (q == 1 or q == 2))
        or (shape == 'SIDE-TOP' and (q == 2 or q == 3))
        or (shape == 'SIDE-BOTTOM' and (q == 1 or q == 4))
        or (shape == 'TRICORNER-TOPRIGHT' and q == 1)
        or (shape == 'TRICORNER-BOTTOMRIGHT' and q == 2)
        or (shape == 'TRICORNER-BOTTOMLEFT' and q == 3)
        or (shape == 'TRICORNER-TOPLEFT' and q == 4)
    if square then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    button:ClearAllPoints()
    button:SetPoint('CENTER', Minimap, 'CENTER', x * halfW, y * halfH)
end

local function SaveAngle(angle)
    if not db then GetDB() end
    db.minimapAngle = angle
end

local function EnsureConfigLoaded()
    local configName = AddonName .. '_Config'

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(configName) then
        return true
    elseif IsAddOnLoaded and IsAddOnLoaded(configName) then
        return true
    end

    -- Load-on-demand addons cannot be loaded once combat lockdown has begun.
    -- The config is preloaded at login below so Full Settings can still open
    -- from the quick menu while the player is already in combat.
    if InCombatLockdown and InCombatLockdown() then
        return false, 'combat lockdown'
    end

    local loaded, reason
    if C_AddOns then
        loaded, reason = C_AddOns.LoadAddOn(configName)
        if not loaded and C_AddOns.IsAddOnLoaded(configName) then loaded = true end
    elseif LoadAddOn then
        loaded, reason = LoadAddOn(configName)
        if not loaded and IsAddOnLoaded and IsAddOnLoaded(configName) then loaded = true end
    end
    return loaded, reason
end

local function OpenOptions()
    -- Blizzard Settings is protected during combat on Midnight. Never try to
    -- show it from an addon while combat lockdown is active, otherwise WoW
    -- reports "Interface action failed because of an AddOn". Use our
    -- already-independent full combat panel instead.
    local inCombat = (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat('player'))
    if inCombat then
        local np = Addon.MidnightNameplates or _G.OmniCC_GODMODE_Nameplates
        if np and np.ShowCombatFullPanel then
            np.ShowCombatFullPanel()
        elseif np and np.ShowQuickPanel then
            np.ShowQuickPanel()
        end
        return
    end

    local loaded, reason = EnsureConfigLoaded()

    if not loaded then
        print('|cffff5555OmniCC GODMODE:|r unable to load settings (' .. tostring(reason or 'unknown') .. ').')
        return
    end

    local function openNow()
        if Addon.OpenOptions then
            Addon:OpenOptions()
        elseif _G.OmniCC_GODMODE and _G.OmniCC_GODMODE.OpenOptions then
            _G.OmniCC_GODMODE:OpenOptions()
        elseif Addon.ShowOptionsFrame then
            Addon:ShowOptionsFrame()
        end
    end

    if C_Timer and C_Timer.After then C_Timer.After(0, openNow) else openNow() end
end

function Addon:OpenFullSettings()
    OpenOptions()
end

-- Preload the standalone GODMODE config while out of combat so the full menu
-- remains available immediately after combat.
local configPreloader = CreateFrame('Frame')
configPreloader:RegisterEvent('PLAYER_LOGIN')
configPreloader:RegisterEvent('PLAYER_REGEN_ENABLED')
configPreloader:SetScript('OnEvent', function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    if EnsureConfigLoaded() then
        self:UnregisterAllEvents()
    end
end)

local function CreateButton()
    if button then return end

    -- Minimap parent enables collector discovery and custom shape positioning.
    button = CreateFrame('Button', 'OmniCC_GODMODE_MinimapButton', Minimap)
    button:SetSize(30, 30)
    button:SetFrameStrata('MEDIUM')
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    button:RegisterForDrag('LeftButton')
    button:SetClampedToScreen(true)

    local border = button:CreateTexture(nil, 'OVERLAY')
    border:SetTexture('Interface/Minimap/MiniMap-TrackingBorder')
    border:SetSize(46, 46)
    border:SetPoint('TOPLEFT')

    local icon = button:CreateTexture(nil, 'BACKGROUND')
    icon:SetTexture(ICON)
    icon:SetSize(18, 18)
    icon:SetPoint('CENTER', 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetTexture('Interface/Minimap/UI-Minimap-ZoomButton-Highlight')
    highlight:SetBlendMode('ADD')
    highlight:SetSize(30, 30)
    highlight:SetPoint('CENTER')

    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:AddLine('OmniCC GODMODE', 1, 0.82, 0)
        GameTooltip:AddLine('Left-click: Full settings / combat quick panel', 1, 1, 1)
        GameTooltip:AddLine('Right-click: Show/hide move anchor', 1, 1, 1)
        GameTooltip:AddLine('Drag: Move button around minimap', 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', GameTooltip_Hide)

    button:SetScript('OnDragStart', function(self)
        self:SetScript('OnUpdate', function()
            if not Minimap then return end
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            SaveAngle(math.deg(math.atan2(cy - my, cx - mx)))
            UpdatePosition()
        end)
    end)

    button:SetScript('OnDragStop', function(self)
        self:SetScript('OnUpdate', nil)
        -- Angle is already stored continuously; write it once more explicitly.
        SaveAngle(db and db.minimapAngle or DEFAULT_ANGLE)
        UpdatePosition()
    end)

    button:SetScript('OnClick', function(_, mouseButton)
        local np = Addon.MidnightNameplates

        if mouseButton == 'RightButton' then
            if Addon.ToggleMidnightQuickMenu then
                Addon:ToggleMidnightQuickMenu()
            end
            return
        end

        local inCombat = (InCombatLockdown and InCombatLockdown())
            or (UnitAffectingCombat and UnitAffectingCombat('player'))
        if inCombat and np and np.ShowQuickPanel then
            np.ShowQuickPanel()
            return
        end

        OpenOptions()
    end)

    UpdatePosition()
    button:SetShown(not db.minimapHidden)
    Addon.MinimapButton = button
end



-- One canonical minimap visibility API.
-- Uses the same persisted Midnight database as the other nameplate/settings toggles.
function Addon:SetMinimapButtonShown(shown)
    shown = shown and true or false
    local settings = GetDB()
    settings.minimapHidden = not shown

    if button then
        if shown then
            button:Show()
            UpdatePosition()
        else
            button:Hide()
        end
    end
end

function Addon:IsMinimapButtonShown()
    local settings = GetDB()
    return settings.minimapHidden ~= true
end

function Addon:ToggleMinimapButton()
    self:SetMinimapButtonShown(not self:IsMinimapButtonShown())
end

local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGOUT')
events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:RegisterEvent('DISPLAY_SIZE_CHANGED')
events:RegisterEvent('UI_SCALE_CHANGED')
events:SetScript('OnEvent', function(_, event, arg1)
    if event == 'ADDON_LOADED' and arg1 == AddonName then
        GetDB()
        CreateButton()
    elseif event == 'ADDON_LOADED' and (arg1 == 'EllesmereUI' or arg1 == 'EllesmereUIMinimap') then
        -- Reassert our independent button after Ellesmere installs its minimap
        -- child-management pass. No changes are made to Ellesmere itself.
        if button then
            button:SetParent(Minimap)
            button:SetFrameStrata('MEDIUM')
            button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
            button:SetShown(not GetDB().minimapHidden)
            UpdatePosition()
        end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        if not button then GetDB(); CreateButton() end
        if button then
            button:SetParent(Minimap)
            button:SetShown(not GetDB().minimapHidden)
            UpdatePosition()
        end
    elseif event == 'PLAYER_LOGOUT' then
        if db and button then
            db.minimapAngle = db.minimapAngle or DEFAULT_ANGLE
            -- Only SetMinimapButtonShown may persist visibility; icon bags hide temporarily.
        end
    elseif event == 'DISPLAY_SIZE_CHANGED' or event == 'UI_SCALE_CHANGED' then
        UpdatePosition()
    end
end)




SLASH_OMNICCGODMODEMINIMAP1 = "/ogmminimap"
SlashCmdList["OMNICCGODMODEMINIMAP"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "hide" or msg == "off" then
        Addon:SetMinimapButtonShown(false)
        print("|cffffd100OmniCC GODMODE:|r minimap button hidden. Use /ogmminimap show to restore it.")
    elseif msg == "toggle" then
        Addon:ToggleMinimapButton()
        print("|cffffd100OmniCC GODMODE:|r minimap button " .. (Addon:IsMinimapButtonShown() and "shown." or "hidden."))
    else
        Addon:SetMinimapButtonShown(true)
        print("|cffffd100OmniCC GODMODE:|r minimap button shown.")
    end
end




-- Midnight: right-click opens only the small Quick Controls panel.
-- Move anchors appear only when Move NPC / Move CC is explicitly pressed.
