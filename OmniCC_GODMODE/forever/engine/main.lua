local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
_G.OmniCC_GODMODE_ClientBackend = 'Forever'
_G.OmniCC_GODMODE_ForeverEngineLoaded = true
local AddonName, Addon = ...
local DB_NAME = 'OmniCC_GODMODE_ForeverDB'

-- active cooldowns
local active = {}

-- text containers for repositioning cooldown font strings
local textContainers = {}
-- Use a stable action-button reference width. Do NOT sample the cooldown
-- width while Lua files are loading: on /reload Blizzard can briefly report a
-- 0/1px or otherwise unfinished width before the action bars finish layout.
-- That poisoned the denominator used by scaleText and made countdown numbers
-- explode to a huge size until a later resize/restyle happened. 36px is the
-- canonical action-button cooldown baseline and keeps reload/login deterministic.
local SCALE_BASE = 36

-- integer id generation to give us a stable not secret identifier
-- we can use for the active table
local nextid
do
    local id = 0
    nextid = function() id = id + 1; return id; end
end

-- themer function cache
local themers = setmetatable({}, {
    __index = function(self, key)
        -- AceDB removes all-default profile tables during PLAYER_LOGOUT.
        -- Cooldown callbacks can still run during teardown, so never assume
        -- profile/themes still exists here.
        local profile = Addon.db and Addon.db.profile
        local themes = profile and profile.themes
        local theme = themes and themes[key]
        if not theme then return nil end

        local themer = Addon:CreateThemer(theme)
        if themer then self[key] = themer end
        return themer
    end
})

local function isGodmodeNameplateCooldown(cooldown)
    -- Positive-only cache: once a cooldown is confirmed as one of our marked
    -- nameplate aura cooldowns, its ownership does not change. This avoids
    -- repeatedly walking up 12 parents on every Blizzard cooldown refresh.
    if cooldown and cooldown.OGMGodmodeNameplateCooldown then return true end

    local region, depth = cooldown, 0
    while region and depth < 12 do
        local okMarker, marker = pcall(function() return region.OGMNameplateAura end)
        if okMarker and marker then
            cooldown.OGMGodmodeNameplateCooldown = true
            return true
        end
        if not region.GetParent then break end
        local okParent, parent = pcall(region.GetParent, region)
        if not okParent then break end
        region = parent
        depth = depth + 1
    end
    return false
end

-- 70170 nameplate countdown stabilization.  Keep Blizzard's existing countdown
-- FontString parent/renderer (the stable pre-70170 behavior), and change only
-- font size, center position and GODMODE duration colors. Reparenting to a 1x1
-- proxy on 70170 can move protected aura text below the icon and make the saved
-- size appear much smaller than requested.
local function stabilizeNameplateCountdownText(cooldown)
    if not isGodmodeNameplateCooldown(cooldown) then return end
    if cooldown.OGMNameplateBoundDuration then return end
    if not cooldown.GetCountdownFontString then return end

    local okText, text = pcall(cooldown.GetCountdownFontString, cooldown)
    if not okText or not text then return end
    if text.IsForbidden and text:IsForbidden() then return end

    local themes = Addon.db and Addon.db.profile and Addon.db.profile.themes
    local theme = themes and themes[(Addon.db.profile.godmodeAutoFitEnabled and 'godmode_autofit') or 'nameplates']
    if not theme then return end

    -- PERFORMANCE: cooldown-start is a global hot path. Never reapply
    -- nameplate swipe/edge/bling/reverse/color here; nameplate aura cooldowns
    -- receive those properties once from their dedicated nameplate renderer.
    -- This restores the 1.3.7 cost model while preserving the 1.3.9 theme.

    -- IMPORTANT: do NOT touch countdown geometry here. The Nameplates theme
    -- themer owns the selected 9-point anchor + X/Y offsets. Older 70170
    -- stabilization code forced CENTER after the themer ran, which is why
    -- RIGHT/TOPRIGHT/TOP/BOTTOM appeared stuck around the middle.

    local fontPath, currentSize, currentFlags
    if text.GetFont then
        local ok, fp, sz, fl = pcall(text.GetFont, text)
        if ok then fontPath, currentSize, currentFlags = fp, sz, fl end
    end
    fontPath = theme.font or fontPath or STANDARD_TEXT_FONT
    local requestedFontSize = tonumber(theme.fontSize) or tonumber(currentSize) or 22
    if requestedFontSize < 6 then requestedFontSize = 6 elseif requestedFontSize > 48 then requestedFontSize = 48 end
    local fontFlags = theme.fontFlags
    if fontFlags == nil then fontFlags = currentFlags end
    if text.SetFont and not theme.autoFitText then
        local ok = pcall(text.SetFont, text, fontPath, requestedFontSize, fontFlags)
        if not ok then pcall(text.SetFont, text, STANDARD_TEXT_FONT, requestedFontSize, fontFlags) end
    end

    if theme.shadowColor and text.SetShadowColor then
        local r,g,b,a = Addon.HexToRGBA(theme.shadowColor)
        pcall(text.SetShadowColor, text, r,g,b,a)
        if text.SetShadowOffset then
            pcall(text.SetShadowOffset, text, tonumber(theme.shadowX) or 0, tonumber(theme.shadowY) or 0)
        end
    end

    -- Formatter ownership stays in the Theme/themer path.  Do not assign a
    -- formatter from the 70170 nameplate stabilizer: SetCountdownFormatter can
    -- rebuild/recenter the FontString and must never participate in geometry.

    -- Never counter-scale nameplate text.  The explicit font size above is the
    -- literal user value; this fixes 70170's tiny text / invisible +/- changes.
    if text.SetScale then pcall(text.SetScale, text, 1) end
    if text.SetAlpha then pcall(text.SetAlpha, text, 1) end
end

-- Recognize the native Threat Plates aura button BEFORE the normal renderer.
-- Do not rely solely on the bridge's optional Icon/Stacks/TimeLeft fields:
-- some aura variants create their cooldown before those regions exist.
local function isThreatPlatesAuraCooldown(cooldown)
    if not cooldown or _G.OmniCC_GODMODE_CooldownsOnly ~= true then return false end
    if cooldown._ogmTPAuraCooldown then return true end
    local ok, match = pcall(function()
        local button = cooldown:GetParent()
        if not button then return false end
        -- TP's CreateAuraFrameIconMode builds Icon + Border + Highlight
        -- BEFORE assigning frame.Cooldown. SetCooldown can fire inside
        -- Addon.CreateCooldown, while frame.Cooldown is still nil.
        -- Never require that assignment to have completed.
        if button.Icon and button.Border and button.Highlight then return true end
        -- TP's alternative aura button layouts expose these regions.
        if button.Cooldown == cooldown and
           (button.TimeLeft or button.TimeText or button.Stacks or button.AuraIcon) then
            return true
        end
        return false
    end)
    if ok and match then
        cooldown._ogmTPAuraCooldown = true
        return true
    end
    return false
end


-- Resolve the owner from the frame chain rather than from theme rules.  Threat
-- Plates may create its cooldown before the aura button's text fields exist.
-- No global nameplate scans and no per-frame polling.
local function isTPNameplateTree(cd)
    if not cd or _G.OmniCC_GODMODE_CooldownsOnly ~= true then return false end
    local ok, found = pcall(function()
        local node = cd
        for _ = 1, 24 do
            if not node then break end
            if node._ogmTPAuraCooldown or node.namePlateUnitToken or node.isNamePlate then return true end
            local name = node.GetName and node:GetName()
            if type(name) == 'string' and
                (name:find('NamePlate') or name:find('nameplate') or
                 name:find('ThreatPlate') or name:find('TidyPlate')) then return true end
            if node.unit and type(node.unit) == 'string' and node.unit:match('^nameplate%d+$') then return true end
            node = node.GetParent and node:GetParent() or nil
        end
        return false
    end)
    return ok and found or false
end

local function threatPlatesOwnsCooldown(cooldown)
    if isThreatPlatesAuraCooldown(cooldown) then return true end
    local bridge=Addon.ForeverThreatPlatesBridge
    return bridge and bridge.OwnsCooldown and bridge:OwnsCooldown(cooldown)
end

-- TP ONLY: two independent countdown text sources exist on an aura icon:
-- Blizzard's Cooldown FontString and Threat Plates' TimeLeft/TimeText.
-- Suppress both without touching the icon, TP bridge, or any other cooldown.
local function suppressTPWhiteText(cd)
    if not cd or _G.OmniCC_GODMODE_CooldownsOnly ~= true or not threatPlatesOwnsCooldown(cd) then return false end
    cd.noCooldownCount = true
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers, cd, true) end
    local function mute(fs)
        if not fs or not fs.Hide then return end
        pcall(fs.Hide, fs)
        if fs.SetAlpha then pcall(fs.SetAlpha, fs, 0) end
        if fs._ogmTPWhiteMuteHooked then return end
        fs._ogmTPWhiteMuteHooked = true
        -- Recycled TP buttons can be shown again by TP/Blizzard after SetCooldown.
        -- Only one hook per FontString; no OnUpdate, polling or nameplate scans.
        if type(fs.Show) == 'function' then
            pcall(hooksecurefunc, fs, 'Show', function(label)
                if _G.OmniCC_GODMODE_CooldownsOnly == true then
                    label:Hide()
                    if label.SetAlpha then label:SetAlpha(0) end
                end
            end)
        end
        if type(fs.SetText) == 'function' then
            pcall(hooksecurefunc, fs, 'SetText', function(label)
                if _G.OmniCC_GODMODE_CooldownsOnly == true then
                    label:Hide()
                    if label.SetAlpha then label:SetAlpha(0) end
                end
            end)
        end
    end
    local ok, native = pcall(function() return cd.GetCountdownFontString and cd:GetCountdownFontString() end)
    if ok then mute(native) end
    local okParent, button = pcall(cd.GetParent, cd)
    if okParent and button then
        mute(button.TimeLeft)
        mute(button.TimeText)
    end
    return true
end

-- A cooldown on a nameplate must never inherit the Action Bars theme.
-- Walk only its own parents (no global nameplate enumeration or OnUpdate).
local function isNameplateDescendant(cooldown)
    if not cooldown then return false end
    local ok, found = pcall(function()
        local node = cooldown
        for depth = 1, 14 do
            if not node then break end
            local name = node.GetName and node:GetName()
            if type(name) == 'string' and (name:find('NamePlate') or name:find('nameplate') or name:find('ThreatPlate')) then
                return true
            end
            if node.namePlateUnitToken or node.isNamePlate or node._ogmTPAuraCooldown then return true end
            node = node.GetParent and node:GetParent() or nil
        end
        return false
    end)
    return ok and found or false
end

-- Cooldowns Only silent nameplate route. This is a virtual disabled theme,
-- never a change to the user's Action Bars theme or its SavedVariables.
-- Use the nameplate ancestry check as well as TP aura detection, so cooldowns
-- with incomplete TP aura fields cannot inherit the Action Bars theme.
local function cooldownsOnlySilentNameplate(cd)
    return _G.OmniCC_GODMODE_CooldownsOnly == true and cd and
        (isTPNameplateTree(cd) or isNameplateDescendant(cd) or threatPlatesOwnsCooldown(cd))
end

-- Optional per-surface ownership. Classification is cached per cooldown frame;
-- no scanning, timers or per-frame polling are introduced.
local ogmSurfaceCache = setmetatable({}, {__mode='k'})
local function ogmCooldownSurface(cd)
    if not cd then return nil end
    -- Do not cache unknown frames: Blizzard can reparent unnamed cooldowns
    -- after creation (bags, pet bars, vehicle bars and temporary aura buttons).
    local cached = ogmSurfaceCache[cd]
    if cached then return cached end
    local node, result = cd, nil
    for _ = 1, 12 do
        if not node then break end
        local okName, name = pcall(node.GetName, node)
        if okName and type(name) == 'string' then
            if name:find('PetActionButton', 1, true) or name:find('PetActionBar', 1, true) then result='pet'; break end
            if name:find('OverrideActionBar', 1, true) or name:find('Vehicle', 1, true) or name:find('PossessButton', 1, true) or name:find('PossessBar', 1, true) then result='vehicle'; break end
            if name:find('ContainerFrame', 1, true) or name:find('BagSlot', 1, true) or name:find('ReagentBag', 1, true) or name:find('ItemButton', 1, true) and (name:find('Bag', 1, true) or name:find('Container', 1, true)) then result='bags'; break end
            if name:find('Character', 1, true) and name:find('Slot', 1, true) or name:find('Inspect', 1, true) and name:find('Slot', 1, true) or name:find('EquipmentFlyout', 1, true) or name:find('Trinket', 1, true) and name:find('Slot', 1, true) then result='equipment'; break end
            if name:find('BuffButton', 1, true) or name:find('DebuffButton', 1, true) or name:find('TemporaryEnchant', 1, true) or name:find('BuffFrame', 1, true) or name:find('DebuffFrame', 1, true) then result='minimapBuffs'; break end
        end
        local okParent, parent = pcall(node.GetParent, node)
        if not okParent or parent == node then break end
        node = parent
    end
    if result then ogmSurfaceCache[cd] = result end
    return result
end
local function ogmSurfaceAllowed(cd)
    local p = Addon.db and Addon.db.profile
    local settings = p and p.godmodeCooldownSurfaces
    if not settings then return true end
    local surface = ogmCooldownSurface(cd)
    return not surface or settings[surface] ~= false
end
local function ogmReleaseSurfaceStyle(cooldown)
    if not cooldown or InCombatLockdown and InCombatLockdown() then return end
    local ok, label = pcall(cooldown.GetCountdownFontString, cooldown)
    if ok and label then
        pcall(label.SetFont, label, STANDARD_TEXT_FONT, 12, '')
        pcall(label.SetScale, label, 1)
        pcall(label.SetAlpha, label, 1)
        pcall(label.SetShadowOffset, label, 0, 0)
    end
    if cooldown.SetHideCountdownNumbers then
        pcall(cooldown.SetHideCountdownNumbers, cooldown, false)
    end
end

local OGMIsNativeActionButtonCooldown
-- All Cooldowns: independent action-bar ownership gate. Do not conflate
-- this switch with the Default theme (used by unrelated cooldowns).
local function ogmActionControlEnabled(cooldown)
    if not cooldown then return true end
    local profile = Addon.db and Addon.db.profile
    local switches = profile and profile.godmodeCooldownSurfaces
    return not (switches and switches.actionbars == false and OGMIsNativeActionButtonCooldown(cooldown))
end
local function ogmReleaseActionStyle(cooldown)
    if not cooldown or not OGMIsNativeActionButtonCooldown(cooldown) then return end
    local ok, label = pcall(cooldown.GetCountdownFontString, cooldown)
    if ok and label then
        pcall(label.SetFont, label, STANDARD_TEXT_FONT, 12, '')
        pcall(label.SetScale, label, 1)
        pcall(label.SetAlpha, label, 1)
        pcall(label.SetShadowOffset, label, 0, 0)
    end
    if cooldown.SetHideCountdownNumbers then
        pcall(cooldown.SetHideCountdownNumbers, cooldown, false)
    end
end
local function getTheme(cooldown)
    if not ogmActionControlEnabled(cooldown) then return nil end
    if not ogmSurfaceAllowed(cooldown) then return nil end
    if cooldownsOnlySilentNameplate(cooldown) then return nil end
    if threatPlatesOwnsCooldown(cooldown) then
        -- Threat Plates uses a GODMODE-owned icon-attached label, not the
        -- generic Blizzard countdown FontString.
        return
    end
    -- Dedicated GODMODE widgets (Player CC) render their own single timer.
    if cooldown and cooldown.noOCC then return end
    -- Cooldowns Only deliberately lets Threat Plates own icon geometry while
    -- GODMODE owns the timer.  Do not let the generic compatibility exclusion
    -- suppress the theme on that same native TP cooldown.
    if not threatPlatesOwnsCooldown(cooldown)
        and Addon.CompatibilityOwnsFrame and Addon:CompatibilityOwnsFrame(cooldown) then return end
    if cooldown.noCooldownCount and not (Addon.GodmodeHardOwnsFrame and Addon:GodmodeHardOwnsFrame(cooldown)) then return end

    local themeName = Addon:GetThemeName(cooldown)
    -- Action Bars theme is for action buttons, never Threat Plates/nameplates.
    -- Do not disable the theme globally: real action-bar countdowns must survive.
    if isNameplateDescendant(cooldown) and themeName ~= 'nameplates' then return end
    local profile = Addon.db and Addon.db.profile
    local themes = profile and profile.themes
    local theme = themes and themes[themeName]

    if theme and theme.enabled then
        return theme
    end
end

-- Threat Plates uses tiny native aura cooldowns. Apply the actual Nameplates
-- theme to GODMODE's existing countdown FontString at a literal font size.
-- This is static styling only; never add an OnUpdate or another timer region.
local OGMHotPathGeneration = 0
local function styleTPNameplateText(cooldown)
    if not threatPlatesOwnsCooldown(cooldown) then return end
    local profile = Addon.db and Addon.db.profile
    local theme = profile and profile.themes and profile.themes.nameplates
    if not theme or not theme.enabled then return end
    -- TP's native Cooldown FontString is the text GODMODE itself enables.
    -- Route this very FontString through the SAME themer/formatter as the
    -- Nameplates preview; setting only its font left duration colors white.
    local generation = OGMHotPathGeneration
    if cooldown._ogmTPThemeGeneration ~= generation then
        local styler = themers.nameplates
        if not styler then
            styler = Addon:CreateThemer(theme)
            themers.nameplates = styler
        end
        if styler then pcall(styler, cooldown) end
        cooldown._ogmTPThemeGeneration = generation
    end
    local fs = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if not fs then return end
    local size = tonumber(theme.fontSize)
    if size and size > 0 then
        local path, _, flags = fs:GetFont()
        local font = path or STANDARD_TEXT_FONT
        if theme.font then
            local media = LibStub('LibSharedMedia-3.0', true)
            font = (media and media:Fetch('font', theme.font)) or font
        end
        pcall(fs.SetFont, fs, font, size, theme.fontFlags or flags)
    end
    -- TP countdowns are Blizzard-owned FontStrings created on third-party icons.
    -- Do not rely on the generic themeText flag / cached generic theme path:
    -- install the actual Nameplates duration/color formatter on THIS cooldown.
    -- Cache the formatter per profile generation to avoid SetCooldown hot-path work.
    if cooldown._ogmTPFormatterGeneration ~= generation then
        if Addon.CreateCountdownFormatter and cooldown.SetCountdownFormatter then
            local ok, formatter = pcall(Addon.CreateCountdownFormatter, Addon, theme)
            if ok and formatter then
                pcall(cooldown.SetCountdownFormatter, cooldown, formatter)
            end
        end
        cooldown._ogmTPFormatterGeneration = generation
    end
    -- The native formatter can recreate/recenter its text region. Re-read it
    -- after assignment and apply the Nameplates font to the final FontString.
    fs = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if fs then
        local size = tonumber(theme.fontSize)
        if size and size > 0 then
            local path, _, flags = fs:GetFont()
            local font = path or STANDARD_TEXT_FONT
            if theme.font then
                local media = LibStub('LibSharedMedia-3.0', true)
                font = (media and media:Fetch('font', theme.font)) or font
            end
            pcall(fs.SetFont, fs, font, size, theme.fontFlags or flags)
        end
        if fs.SetScale then pcall(fs.SetScale, fs, 1) end
    end
    if Addon.ApplyCountdownTextPosition then
        pcall(Addon.ApplyCountdownTextPosition, Addon, cooldown, theme)
    end
end


-- GODMODE-owned countdown overlay for Threat Plates' EXISTING aura icons.
-- Blizzard's native white number is hidden; no icon is created or moved.
local tpOverlayFrames = setmetatable({}, {__mode = 'k'})
local tpOverlayTicker
local function tpOverlayColor(value)
    if type(value) == 'table' then
        local r,g,b,a = value.r or value[1], value.g or value[2], value.b or value[3], value.a or value[4] or 1
        if type(r)=='number' and type(g)=='number' and type(b)=='number' then return r,g,b,a end
    end
    if type(value)=='string' then
        local h=value:gsub('^#',''):gsub('^|c',''):gsub('^|C','')
        if h:match('^%x%x%x%x%x%x$') then
            return tonumber(h:sub(1,2),16)/255,tonumber(h:sub(3,4),16)/255,tonumber(h:sub(5,6),16)/255,1
        elseif h:match('^%x%x%x%x%x%x%x%x$') then
            -- GODMODE stores eight-digit colors in Blizzard AARRGGBB order.
            return tonumber(h:sub(3,4),16)/255,tonumber(h:sub(5,6),16)/255,tonumber(h:sub(7,8),16)/255,tonumber(h:sub(1,2),16)/255
        end
    end
    return 1,1,1,1
end
local function tpOverlayStyle(cd, label)
    local p = Addon.db and Addon.db.profile
    local t = p and p.themes and p.themes.nameplates
    if not t then return end
    local media = LibStub and LibStub('LibSharedMedia-3.0', true)
    local path = t.font and media and media:Fetch('font', t.font) or STANDARD_TEXT_FONT
    local size = tonumber(t.fontSize) or 10
    if size < 4 then size = 4 elseif size > 60 then size = 60 end
    pcall(label.SetFont, label, path, size, t.fontFlags or 'OUTLINE')
    label:ClearAllPoints()
    -- Anchor to the real TP icon, not the cooldown's swipe/number region.
    local button = cd:GetParent()
    local icon = button and button.Icon
    label:SetPoint(t.point or 'CENTER', button or cd, t.point or 'CENTER', tonumber(t.offsetX) or 0, tonumber(t.offsetY) or 0)
    label:SetScale(1)
end
local function tpOverlayUpdate(cd)
    local label=tpOverlayFrames[cd]
    if not label then return end
    if _G.OmniCC_GODMODE_CooldownsOnly ~= true or not threatPlatesOwnsCooldown(cd) then
        label:Hide(); tpOverlayFrames[cd]=nil; return
    end
    local button=cd:GetParent()
    if not button or not button:IsShown() then label:Hide(); return end
    local ok,start,duration=false,nil,nil
    if type(cd.GetCooldownTimes)=='function' then
        ok,start,duration=pcall(cd.GetCooldownTimes,cd)
    end
    if ok and issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then ok=false end
    if (not ok or type(start)~='number' or type(duration)~='number' or duration<=0)
        and cd._ogmTPStart and cd._ogmTPDuration then
        start,duration=cd._ogmTPStart,cd._ogmTPDuration
        ok=true
    end
    if not ok or (issecretvalue and (issecretvalue(start) or issecretvalue(duration)))
        or type(start)~='number' or type(duration)~='number' or duration<=0 then label:Hide(); return end
    local remaining=(start+duration)/1000-GetTime()
    if remaining<=0 then label:Hide(); return end
    local p=Addon.db and Addon.db.profile
    local theme=p and p.themes and p.themes.nameplates
    if not theme or theme.enabled==false then label:Hide(); return end
    local minimum=tonumber(theme.minDuration) or 0
    if duration/1000<minimum then label:Hide(); return end
    local str
    if remaining >= 3600 then str=string.format('%dh',math.ceil(remaining/3600))
    elseif remaining >= 60 then str=string.format('%dm',math.ceil(remaining/60))
    elseif remaining >= 10 then str=tostring(math.ceil(remaining))
    else str=string.format('%.1f',remaining) end
    -- Avoid redundant native FontString mutations on every timer tick.
    -- Countdown appearance still updates whenever its displayed value changes.
    if label._ogmTPDisplayedText ~= str then
        label:SetText(str)
        label._ogmTPDisplayedText = str
    end
    local color=theme.defaultTextColor
    if type(theme.textColors)=='table' then
        -- Match engine/themer.lua getColorBreakpoints(): an entry color
        -- applies BELOW its threshold; default color applies above all.
        local bestThreshold
        for _,entry in ipairs(theme.textColors) do
            local threshold=type(entry)=='table' and tonumber(entry.threshold)
            if threshold and remaining <= threshold and (not bestThreshold or threshold < bestThreshold) then
                color=entry.color; bestThreshold=threshold
            end
        end
    end
    local r,g,b,a=tpOverlayColor(color)
    if label._ogmTPColorR ~= r or label._ogmTPColorG ~= g
        or label._ogmTPColorB ~= b or label._ogmTPColorA ~= a then
        label:SetTextColor(r,g,b,a)
        label._ogmTPColorR,label._ogmTPColorG= r,g
        label._ogmTPColorB,label._ogmTPColorA= b,a
    end
    if not label:IsShown() then label:Show() end
end
local function tpOverlayRegister(cd)
    if not cd or not threatPlatesOwnsCooldown(cd) then return end
    cd.noCooldownCount = true
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers,cd,true) end
    local label=tpOverlayFrames[cd]
    if not label then
        -- Threat Plates Forever places its TimeLeft on a dedicated text_frame
        -- ABOVE the cooldown. Creating our text on the cooldown makes it render
        -- behind that layer or at the wrong scale. Share TP's text layer.
        local button=cd:GetParent()
        local native=button and (button.TimeLeft or button.TimeText)
        local textLayer=native and native.GetParent and native:GetParent()
        if not textLayer or not textLayer.CreateFontString then textLayer=button or cd end
        label=textLayer:CreateFontString(nil,'OVERLAY','GameFontNormal')
        label:SetDrawLayer('OVERLAY',7)
        tpOverlayFrames[cd]=label
    end
    tpOverlayStyle(cd,label)
    tpOverlayUpdate(cd)
    if not tpOverlayTicker then
        tpOverlayTicker=C_Timer.NewTicker(0.2,function()
            -- Cooldowns Only is a global mode; when disabled, release all
            -- registered overlays and stop polling rather than checking each
            -- Threat Plates cooldown separately on every tick.
            if _G.OmniCC_GODMODE_CooldownsOnly ~= true then
                for frame,label in pairs(tpOverlayFrames) do
                    label:Hide()
                    tpOverlayFrames[frame]=nil
                end
                if tpOverlayTicker then tpOverlayTicker:Cancel();tpOverlayTicker=nil end
                return
            end
            local any=false
            for frame in pairs(tpOverlayFrames) do
                any=true
                tpOverlayUpdate(frame)
            end
            if not any and tpOverlayTicker then tpOverlayTicker:Cancel();tpOverlayTicker=nil end
        end)
    end
end


-- Auto-Fit: measure the ACTUAL glyphs after theme styling, not a guessed
-- character count. This is static/size-change work, never an OnUpdate scan.
function Addon:FitAutoText(fs, icon, theme)
    if not fs or not icon or not theme or not theme.autoFitText then return false end
    -- Cooldown frames can cover entire bars or overlays. Select the smallest
    -- plausible visible button ancestor instead of using their huge dimensions.
    local w, h, scale
    local node = icon
    for _ = 1, 5 do
        if not node then break end
        local ok, nw, nh, ns = pcall(function()
            return node:GetWidth(), node:GetHeight(), node:GetEffectiveScale()
        end)
        if ok and type(nw)=='number' and type(nh)=='number'
            and canaccessvalue(nw) and canaccessvalue(nh)
            and nw >= 8 and nh >= 8 and nw <= 160 and nh <= 160
            and type(ns)=='number' and canaccessvalue(ns) and ns > 0 then
            if not w or (nw*nh < w*h) then w,h,scale=nw,nh,ns end
        end
        node = node.GetParent and node:GetParent() or nil
    end
    if not w then
        -- Never show uncontrolled screen-sized text for unbounded frames.
        pcall(fs.SetAlpha, fs, 0)
        return false
    end
    local okFont, path, _, flags = pcall(fs.GetFont, fs)
    if not okFont or not path then return false end
    local okScale, textScale = pcall(fs.GetEffectiveScale, fs)
    if not okScale or type(textScale)~='number' or not canaccessvalue(textScale)
        or textScale <= 0 then textScale = scale end
    local ratio = math.min(1, scale / textScale)
    local maxW = math.max(2, (w-2)*ratio)
    local maxH = math.max(2, (h-2)*ratio)
    -- A countdown FontString can be reparented to an elevated text overlay.
    -- Limit its actual layout box as well as the glyph font size.
    -- Measure unbounded glyph width BEFORE constraining the visible layout box.
    -- A pre-clipped FontString may report its clipped width as if it fits.
    pcall(fs.SetWidth, fs, 1024)
    pcall(fs.SetHeight, fs, maxH)
    if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
    if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 1) end
    -- Font-size preference is a percentage, NOT a fixed glyph size.  Fit the
    -- current fully formatted string (e.g. 1:30) into the icon every time.
    local percent = math.max(0, math.min(99, tonumber(theme.fontSize) or 99))
    local preferred = 5 + 10 * percent / 99
    local size = math.min(preferred, maxH, maxW)
    pcall(fs.SetScale, fs, 1)
    local okText, currentText = pcall(fs.GetText, fs)
    if okText and type(currentText)=='string' and #currentText > 1 then
        -- A preliminary width estimate only; actual glyph measurements below
        -- decide the final size, including punctuation and variable-width fonts.
        size = math.min(size, maxW / (#currentText * 0.45))
    end
    local fitted = false
    for _=1,24 do
        if not pcall(fs.SetFont, fs, path, math.max(1,size), flags) then break end
        local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
        local ow, tw = pcall(measure, fs)
        local oh, th = pcall(fs.GetStringHeight, fs)
        if ow and oh and type(tw)=='number' and type(th)=='number'
            and canaccessvalue(tw) and canaccessvalue(th)
            and tw <= maxW*0.94 and th <= maxH*0.90 then
            fitted = true
            break
        end
        size = size * 0.88
    end
    pcall(fs.SetWidth, fs, maxW)
    pcall(fs.SetHeight, fs, maxH)
    if fitted then
        -- Native cooldown text can change from 90 to 1:30 without SetCooldown,
        -- OnSizeChanged, or any Lua SetText call. Refit on displayed text changes.
        fs._ogmFitIcon, fs._ogmFitTheme = icon, theme
        if not fs._ogmFitWatchInstalled and fs.HookScript then
            fs._ogmFitWatchInstalled = true
            fs._ogmFitLastText = currentText
            fs._ogmFitElapsed = 0
            pcall(fs.HookScript, fs, 'OnUpdate', function(label, elapsed)
                if not label._ogmFitTheme or not label._ogmFitTheme.autoFitText then return end
                label._ogmFitElapsed = (label._ogmFitElapsed or 0) + elapsed
                if label._ogmFitElapsed < 0.15 then return end
                label._ogmFitElapsed = 0
                local ok, value = pcall(label.GetText, label)
                if not ok or type(value) ~= 'string' or value == label._ogmFitLastText then return end
                label._ogmFitLastText = value
                Addon:FitAutoText(label, label._ogmFitIcon, label._ogmFitTheme)
            end)
        end
        fs._ogmFitLastText = currentText
        pcall(fs.SetAlpha, fs, 1)
        return true
    end
    pcall(fs.SetAlpha, fs, 0)
    return false
end

local function onCooldownSizeChanged(cooldown, width)
    if threatPlatesOwnsCooldown(cooldown) then
        -- TP uses an independent GODMODE text overlay, never native countdown.
        cooldown.noCooldownCount = true
    end
    -- Unit aura timers have their own Forever GODMODE size controls. Do not
    -- let OmniCC's generic cooldown-size threshold hide or rescale them.
    local auraAutoFit = Addon.db and Addon.db.profile and Addon.db.profile.godmodeAutoFitEnabled
    if not auraAutoFit and Addon.ForeverAuraText and Addon.ForeverAuraText.Classify and Addon.ForeverAuraText:Classify(cooldown) then
        local fs = cooldown:GetCountdownFontString()
        if fs then fs:SetAlpha(1); fs:SetScale(1) end
        Addon.ForeverAuraText:Apply(cooldown)
        return
    end

    local theme = getTheme(cooldown)
    local scale, alpha = 1, 1

    if theme and not (cooldown._ogmTPAuraCooldown and _G.OmniCC_GODMODE_CooldownsOnly == true) and canaccessvalue(width) and width > 0 then
        scale = theme.scaleText and (Round(width) / SCALE_BASE) or 1
        -- Defensive guard for unusual/temporarily malformed frame widths.
        -- Normal action buttons remain ~1.0; this only prevents a bad UI-layout
        -- value from turning a countdown into screen-sized text.
        if scale < 0.25 then scale = 0.25 elseif scale > 3 then scale = 3 end
        alpha = Round(scale * 100) >= Round(theme.minScale * 100) and 1 or 0
    end

    local fs = cooldown:GetCountdownFontString()
    if theme and theme.autoFitText and fs then
        local icon = cooldown
        local parent = cooldown.GetParent and cooldown:GetParent()
        if parent and parent.GetWidth and parent.GetHeight then
            local ok, pw, ph = pcall(function() return parent:GetWidth(),parent:GetHeight() end)
            if ok and type(pw)=='number' and type(ph)=='number'
                and canaccessvalue(pw) and canaccessvalue(ph)
                and pw > 0 and ph > 0 then
                local okCD, cw, ch = pcall(function() return cooldown:GetWidth(),cooldown:GetHeight() end)
                if okCD and type(cw)=='number' and type(ch)=='number'
                    and canaccessvalue(cw) and canaccessvalue(ch)
                    and (pw < cw or ph < ch) then icon=parent end
            end
        end
        Addon:FitAutoText(fs,icon,theme)
    elseif fs then
        fs:SetAlpha(alpha)
        fs:SetScale(scale)
    end

    if isGodmodeNameplateCooldown(cooldown) then
        stabilizeNameplateCountdownText(cooldown)
    end
end

-- Refresh only currently active GODMODE-owned nameplate countdown text after
-- the dedicated CD-size control changes the Nameplates theme. Geometry and all
-- non-nameplate cooldowns are deliberately untouched.
-- Re-theme existing nameplate cooldowns without rebuilding their icons.
-- The previous implementation cleared the theme cache and then read nil,
-- so neither font nor colors could ever refresh on an active TP aura.
function Addon:RefreshGodmodeNameplateTextStyle()
    -- Rebuild the cached Nameplates themer from the current profile.
    -- A nil cache read must not abort the live refresh.
    themers.nameplates = nil
    local profile = Addon.db and Addon.db.profile
    local theme = profile and profile.themes and profile.themes.nameplates
    local themer = theme and Addon:CreateThemer(theme)
    if not themer then return end
    themers.nameplates = themer
    for _, cooldown in pairs(active) do
        if cooldown and (isGodmodeNameplateCooldown(cooldown)
            or (_G.OmniCC_GODMODE_CooldownsOnly == true and cooldown._ogmTPAuraCooldown)) then
            if not threatPlatesOwnsCooldown(cooldown) then
                pcall(themer, cooldown)
            end
            -- Reapply on the live TP cooldown text even when the native
            -- aura widget has updated its FontString since last styling.
            cooldown._ogmTPThemeGeneration = nil
            if threatPlatesOwnsCooldown(cooldown) then
                local label=tpOverlayFrames[cooldown]
                if label then tpOverlayStyle(cooldown,label); tpOverlayUpdate(cooldown) end
            else
                styleTPNameplateText(cooldown)
            end
            if cooldown._ogmTPAuraCooldown then
                -- TP aura icons are often much smaller than action buttons;
                -- their width must not rescale the configured font size.
                local fs = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
                if fs and fs.SetScale then pcall(fs.SetScale, fs, 1) end
            elseif cooldown.GetWidth then
                local ok, width = pcall(cooldown.GetWidth, cooldown)
                if ok and canaccessvalue(width) then
                    pcall(onCooldownSizeChanged, cooldown, width)
                end
            end
        end
    end
end

-- Isolate Blizzard's native Damage Meter from GODMODE's global cooldown hooks.
-- Check only frame ancestry/name; never read secret combat-session durations.
-- Single protected ancestry traversal for both Blizzard-owned cooldown families.
-- Cache by cooldown frame and immediate parent, preserving reparent detection.
-- Weak keys avoid retaining recycled cooldown widgets.
local ogmBlizzardAncestryCache = setmetatable({}, { __mode = "k" })
local function isBlizzardExcludedCooldown(frame)
    if not frame then return false end
    local parentOK, currentParent = pcall(frame.GetParent, frame)
    if not parentOK then return false end
    local cached = ogmBlizzardAncestryCache[frame]
    if cached and cached.parent == currentParent then return cached.result end
    local original = frame
    local result = false
    for _ = 1, 12 do
        if not frame then break end
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == 'string' and not (issecretvalue and issecretvalue(name)) then
            if name:find('ProfessionsSpec', 1, true)
                or name:find('ProfessionsFrame', 1, true)
                or name:find('ProfessionsSpecialization', 1, true)
                or name:find('HousingDashboard', 1, true)
                or name:find('HousingCatalog', 1, true)
                or name:find('HousingDecor', 1, true)
                or name:find('DamageMeter', 1, true)
                -- Blizzard's center-screen Loss of Control UI owns its own
                -- icon, red backdrop and remaining-duration text. Never let
                -- GODMODE's global cooldown hooks modify this hierarchy.
                -- This is distinct from action-button lossOfControlCooldown.
                or name == 'LossOfControlFrame'
                or name:sub(1, 19) == 'LossOfControlFrame'
                or name:find('MultiCastActionButton', 1, true)
                -- Leave Blizzard arena frame visibility and cooldowns fully native.
                or name:find('CompactArenaFrame', 1, true)
                or name:find('ArenaEnemyFrame', 1, true) then
                result = true
                break
            end
        end
        local pok, parent = pcall(frame.GetParent, frame)
        if not pok or parent == frame then break end
        frame = parent
    end
    ogmBlizzardAncestryCache[original] = { parent = currentParent, result = result }
    return result
end

-- Internal cleanup for cooldowns already classified by onCooldownStart.
-- Avoid repeating both protected ancestry checks on every early return.
local function clearActiveCooldown(cooldown)
    local cooldownID = cooldown.tullaCTC
    if cooldownID then active[cooldownID] = nil end
end

-- User-defined exact frame exclusions. This is a narrow early-out and does not
-- change Blizzard's cooldown, swipe, or native text ownership.
local function ogmExcludedFrame(cooldown)
    local profile = Addon.db and Addon.db.profile
    local exclusions = profile and profile.godmodeExcludedFrames
    local frame = cooldown
    for _ = 1, 12 do
        if not frame then break end
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" then
            -- Blizzard PvP overview / honor-rank badges can contain hidden
            -- Cooldown widgets used for UI animations. These are not spells.
            -- Exclude the entire PvP UI ancestry, not only one badge ID.
            -- Forever's PvP rank screen is PVPRankFrame, not PVPFrame.
            -- Match its exact root or descendants; do not suppress other PvP cooldowns.
            local pvpRankBadge = name == "PVPRankFrame"
                or name:sub(1, 13) == "PVPRankFrame."
            local blizzardPvPUI = name == "PVPFrame"
                or name == "PVPUIFrame"
                or name == "HonorFrame"
                or name == "PVPQueueFrame"
                or name == "PVPMatchFrame"
                or name:find("PVPFrame", 1, true)
                or name:find("PVPUIFrame", 1, true)
                or name:find("HonorFrame", 1, true)
                or name:find("PVPQueueFrame", 1, true)
                or name:find("PVPSeason", 1, true)
                or name:find("PVPMatch", 1, true)
            if pvpRankBadge or blizzardPvPUI or name == "ShamanPowerCD1_7" or (exclusions and exclusions[name]) then
                return true
            end
        end
        if not frame.GetParent then break end
        local okParent, parent = pcall(frame.GetParent, frame)
        if not okParent or parent == frame then break end
        frame = parent
    end
    return false
end

-- Forever PvP rank emblem is a decorative progress badge, not a spell.
-- Mark only cooldowns descending from PVPRankFrame; never alter the badge,
-- Blizzard's rank progress, or other PvP/action-bar cooldowns.
local function ogmIsPvPRankCooldown(cooldown)
    if cooldown._ogmPvPRankTimerSuppressed then return true end
    local frame = cooldown
    for _ = 1, 12 do
        if not frame then break end
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == 'string' and
            (name == 'PVPRankFrame' or name:sub(1, 13) == 'PVPRankFrame.') then
            cooldown._ogmPvPRankTimerSuppressed = true
            return true
        end
        if not frame.GetParent then break end
        local okParent, parent = pcall(frame.GetParent, frame)
        if not okParent or parent == frame then break end
        frame = parent
    end
    return false
end

local function onCooldownStop(cooldown)
    if isBlizzardExcludedCooldown(cooldown) then return end
    clearActiveCooldown(cooldown)
end

-- GODMODE 1.3.9 CAST HOT-PATH CACHE. Invalidated by Addon:Refresh().

local function onCooldownStart(cooldown, startArg, durationArg)
    if ogmExcludedFrame(cooldown) then
        -- Mark the decorative PvP badge before calling SetHideCountdownNumbers:
        -- a later theme hook must never turn its native timer back on.
        if ogmIsPvPRankCooldown(cooldown) then
            cooldown.noCooldownCount = true
        end
        -- Clear a previously attached GODMODE countdown immediately. Merely
        -- removing it from active[] leaves its old FontString visible.
        if cooldown.tullaCTC then
            local fs = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
            if fs and fs.SetText then pcall(fs.SetText, fs, "") end
        end
        if cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
        end
        clearActiveCooldown(cooldown)
        return
    end
    if isBlizzardExcludedCooldown(cooldown) then return end
    if cooldownsOnlySilentNameplate(cooldown) then
        suppressTPWhiteText(cooldown)
        local old = tpOverlayFrames[cooldown]
        if old then old:Hide(); tpOverlayFrames[cooldown] = nil end
        cooldown.noCooldownCount = true
        if cooldown.SetHideCountdownNumbers then pcall(cooldown.SetHideCountdownNumbers, cooldown, true) end
        clearActiveCooldown(cooldown)
        return
    end
    -- TP aura icon: mute BOTH white text sources before any generic renderer.
    if suppressTPWhiteText(cooldown) then
        local old = tpOverlayFrames[cooldown]
        if old then old:Hide(); tpOverlayFrames[cooldown] = nil end
        clearActiveCooldown(cooldown)
        return
    end
    -- Nameplate aura cooldowns are not Action Bars cooldowns.  If TP's
    -- button fields were not ready when SetCooldown fired, ancestry still
    -- catches the frame here before Default/Action Bars can render white text.
    if isTPNameplateTree(cooldown) then
        cooldown.noCooldownCount = true
        if cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
        end
        local button = cooldown.GetParent and cooldown:GetParent()
        if button then
            for _, field in ipairs({'TimeLeft', 'TimeText'}) do
                local label = button[field]
                if label and label.Hide then pcall(label.Hide, label) end
            end
        end
        clearActiveCooldown(cooldown)
        return
    end
    -- Theme preview owns its own single FontString/timer. Do not register it in
    -- the normal GODMODE cooldown engine or a second countdown is rendered.
    if cooldown and cooldown.OGMThemePreview then
        cooldown.noCooldownCount = true
        if cooldown.SetHideCountdownNumbers then pcall(cooldown.SetHideCountdownNumbers, cooldown, true) end
        clearActiveCooldown(cooldown)
        return
    end
    -- Cooldowns Only: the existing TP icon gets ONLY our independent overlay.
    -- Never enter generic OmniCC/native countdown styling for this frame.
    local tpTimerOnly = threatPlatesOwnsCooldown(cooldown)
    if tpTimerOnly then
        -- Capture SetCooldown(start, duration) directly for clients where
        -- GetCooldownTimes is unavailable or does not expose numeric values.
        if type(startArg)=='number' and type(durationArg)=='number'
            and not (issecretvalue and (issecretvalue(startArg) or issecretvalue(durationArg))) then
            cooldown._ogmTPStart=startArg*1000
            cooldown._ogmTPDuration=durationArg*1000
        end
        cooldown.noCooldownCount = true
        if cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
        end
        -- Threat Plates' own duration label is separate from its icon.
        local button = cooldown.GetParent and cooldown:GetParent()
        local native = button and (button.TimeLeft or button.TimeText)
        if native then
            if not cooldown._ogmTPNativeDurationHooked then
                cooldown._ogmTPNativeDurationHooked = true
                hooksecurefunc(native, 'Show', function(label)
                    if _G.OmniCC_GODMODE_CooldownsOnly == true then label:Hide() end
                end)
            end
            native:Hide()
        end
        -- tpOverlayRegister disabled: old separate white-number renderer
        return
    end
    if tpTimerOnly then
        -- Threat Plates owns the icon, but its separate TimeLeft label must
        -- never compete with GODMODE's themed Cooldown FontString.  TP calls
        -- TimeLeft:Show() again when refreshing an existing aura button.
        local button = cooldown.GetParent and cooldown:GetParent()
        local native = button and button.TimeLeft
        if native and not cooldown._ogmTPNativeDurationHooked then
            cooldown._ogmTPNativeDurationHooked = true
            if type(native.Show) == 'function' then
                hooksecurefunc(native, 'Show', function(label)
                    if _G.OmniCC_GODMODE_CooldownsOnly == true then
                        label:Hide()
                    end
                end)
            end
            if type(native.SetShown) == 'function' then
                hooksecurefunc(native, 'SetShown', function(label)
                    if _G.OmniCC_GODMODE_CooldownsOnly == true then
                        label:Hide()
                    end
                end)
            end
        end
        if native and native.Hide then pcall(native.Hide, native) end
    end
    if tpTimerOnly then
        -- Threat Plates' separate TimeLeft FontString is NOT its cooldown
        -- number.  Its own ShowDuration option can leave this native label
        -- visible on already-live buttons even after the widget refresh.
        -- Suppress only that TP-owned label, never the icon or cooldown.
        local tpButton = cooldown:GetParent()
        if tpButton and tpButton.TimeLeft and tpButton.TimeLeft.Hide then
            pcall(tpButton.TimeLeft.Hide, tpButton.TimeLeft)
        end
    end
    if tpTimerOnly then
        -- GODMODE renders the countdown on TP's existing aura cooldown.
        cooldown.noCooldownCount = false
    end
    -- Player CC owns its timer FontString. Never let the generic OmniCC engine
    -- clear noCooldownCount or create the second decimal countdown.
    if cooldown and cooldown.noOCC then
        -- Player CC's duration-object path needs Blizzard's own countdown.
        -- Keep generic GODMODE timers excluded without hiding that number.
        if not cooldown.OGMPlayerCCNativeCountdown and cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
        end
        clearActiveCooldown(cooldown)
        return
    end
    -- CAMERA HOT-PATH: secure GODMODE nameplate AuraButtons own their duration
    -- renderer. Blizzard can call SetCooldown repeatedly while plates enter/leave view;
    -- exit before any compatibility/ancestry/theme classification.
    if cooldown and cooldown.OGMNameplateBoundDuration then
        if cooldown.SetHideCountdownNumbers then pcall(cooldown.SetHideCountdownNumbers, cooldown, true) end
        clearActiveCooldown(cooldown)
        return
    end

    -- CAST/GCD HOT PATH: Blizzard can call SetCooldown on many action buttons for
    -- one key press. Compatibility ownership is structural for a cooldown frame,
    -- so cache it until Refresh() changes rules/settings instead of walking the
    -- parent chain again for every GCD pulse.
    local compatOwns
    if cooldown._ogmCompatGeneration == OGMHotPathGeneration then
        compatOwns = cooldown._ogmCompatOwns
    else
        compatOwns = Addon.CompatibilityOwnsFrame and Addon:CompatibilityOwnsFrame(cooldown) or false
        cooldown._ogmCompatGeneration = OGMHotPathGeneration
        cooldown._ogmCompatOwns = compatOwns and true or false
    end
    if compatOwns and not tpTimerOnly then
        clearActiveCooldown(cooldown)
        return
    else
        cooldown.noCooldownCount = nil
    end

    -- TargetFrame auras use the dedicated Forever duration bridge below the
    -- icon.  Never let OmniCC also activate Blizzard's native centered
    -- countdown on the same aura, otherwise the two texts visibly alternate
    -- whenever Blizzard refreshes TargetFrame auras.
    if cooldown.OGMTargetAuraNativeSuppressed then
        if cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
        end
        clearActiveCooldown(cooldown)
        return
    end

    if cooldown.noCooldownCount then
        clearActiveCooldown(cooldown)
        return
    end

    -- Forever SELF/TARGET/Blizzard aura cooldowns are owned by the dedicated
    -- Buffs / Debuffs controller.  The global Themes panel must NEVER style
    -- these cooldowns: doing so makes a Theme font-size change blow up HoT/
    -- debuff text on unit frames and then the aura controller fights it back.
    -- Apply the dedicated aura settings only and keep this cooldown out of the
    -- generic OmniCC active/theme refresh list.
    local auraOwned
    if cooldown._ogmAuraClassGeneration == OGMHotPathGeneration then
        auraOwned = cooldown._ogmAuraClassOwned
    else
        auraOwned = Addon.ForeverAuraText and Addon.ForeverAuraText.Classify and Addon.ForeverAuraText:Classify(cooldown) or false
        cooldown._ogmAuraClassGeneration = OGMHotPathGeneration
        cooldown._ogmAuraClassOwned = auraOwned and true or false
    end
    if auraOwned then
        if Addon.ForeverAuraText.Apply then Addon.ForeverAuraText:Apply(cooldown) end
        clearActiveCooldown(cooldown)
        return
    end

    local cooldownID = cooldown.tullaCTC
    if cooldownID == nil then
        cooldownID = nextid()
        cooldown.tullaCTC = cooldownID
        cooldown:HookScript('OnSizeChanged', onCooldownSizeChanged)
        cooldown:HookScript('OnCooldownDone', onCooldownStop)
    end

    -- HACK: cooldown text appears below action button hotkey and count text
    -- fix this by reparenting the text to a container with a higher frame
    -- level than the base text overlay container
    local parent = cooldown:GetParent()
    -- GODMODE nameplate aura text must keep Blizzard's original parent.  The
    -- historical action-button overlay reparenting is for action buttons only.
    if not isGodmodeNameplateCooldown(cooldown) and parent and parent.TextOverlayContainer and not InCombatLockdown() then
        local container = textContainers[cooldownID]
        if not container then
            container = CreateFrame('Frame', nil, cooldown)

            container:SetAllPoints(cooldown)
            container:SetFrameLevel(777)
            if container.SetClipsChildren then container:SetClipsChildren(true) end
            cooldown:GetCountdownFontString():SetParent(container)

            textContainers[cooldownID] = container
        end
    end

    local themeName
    if cooldown._ogmThemeGeneration == OGMHotPathGeneration then
        themeName = cooldown._ogmThemeName
    else
        themeName = Addon:GetThemeName(cooldown)
        cooldown._ogmThemeGeneration = OGMHotPathGeneration
        cooldown._ogmThemeName = themeName
    end
    -- CAST/GCD ZERO-LAG: theme application and size styling are static work.
    -- Blizzard pulses SetCooldown across the action bars on every key press; do
    -- not repaint an unchanged frame for every GCD pulse. Refresh() bumps the
    -- generation, and a real width change still forces one restyle.
    -- SECRET-SAFE / CAST HOTPATH LOCK: GetWidth() can be a protected secret
    -- number on Forever while tainted. Never compare/cache it from SetCooldown.
    -- Static styling is generation-driven only; explicit Refresh/size callbacks
    -- own geometry changes. This keeps every GCD pulse out of layout work.
    local needsStaticStyle = cooldown._ogmStaticStyleGeneration ~= OGMHotPathGeneration
    if needsStaticStyle then
        local themer = ogmActionControlEnabled(cooldown) and ogmSurfaceAllowed(cooldown) and themers[themeName]
        if themer then themer(cooldown) end
        if ogmActionControlEnabled(cooldown) and ogmSurfaceAllowed(cooldown) and themeName == 'godmode_autofit' then
            local okWidth, safeWidth = pcall(cooldown.GetWidth, cooldown)
            if okWidth and type(safeWidth) == 'number' and canaccessvalue(safeWidth) then
                onCooldownSizeChanged(cooldown, safeWidth)
            end
        end
        if tpTimerOnly then styleTPNameplateText(cooldown) end
        if tpTimerOnly then
            -- Apply the Nameplates theme to the actual TP cooldown's native
            -- countdown FontString; do not create a second text region.
            local fs = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
            if fs then
                local theme = Addon.db and Addon.db.profile and Addon.db.profile.themes
                theme = theme and theme.nameplates
                if theme and theme.enabled then
                    -- The themer above owns all font/color/anchor choices.
                    -- Only undo TP's initial hidden countdown flag.
                    if cooldown.SetHideCountdownNumbers then
                        pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
                    end
                end
            end
        end
        cooldown._ogmStaticStyleGeneration = OGMHotPathGeneration

        local okWidth, currentWidth = pcall(cooldown.GetWidth, cooldown)
        if okWidth and canaccessvalue(currentWidth) then
            onCooldownSizeChanged(cooldown, currentWidth)
        end
    end
    if tpTimerOnly then
        -- tpOverlayRegister disabled: old separate white-number renderer
    end
    active[cooldownID] = cooldown

    -- Midnight parity: Blizzard may replace a newly cast action-button label
    -- after SetCooldown. Reapply the native font on the next frame, once per
    -- active cooldown. No extra text objects and no repeated world scans.
    if not auraOwned and Addon.StyleLiveActionButton and not cooldown._ogmActionStylePending then
        local parent = cooldown.GetParent and cooldown:GetParent()
        local okName, name = parent and parent.GetName and pcall(parent.GetName, parent)
        if okName and type(name) == 'string' and
            (name:match('^ActionButton%d+$') or name:match('^MultiBar[%w_]+Button%d+$')
             or name:match('^OverrideActionBarButton%d+$') or name:match('^PetActionButton%d+$')
             or name:match('^StanceButton%d+$')) then
            cooldown._ogmActionStylePending = true
            C_Timer.After(0, function()
                cooldown._ogmActionStylePending = nil
                if active[cooldownID] == cooldown then
                    Addon.StyleLiveActionButton(cooldown)
                end
            end)
        end
    end

    -- Only Blizzard PLAYER aura cooldowns need the historical next-frame
    -- font correction. The old code queued this extra styling pass for every
    -- action button / item / unit-frame cooldown in the UI, effectively doing
    -- the expensive theme work twice during combat bursts. Nameplates already
    -- have their dedicated stabilizer and TargetFrame native timers are
    -- suppressed by the 1.2.6 bridge, so keep the delayed pass narrowly scoped.
    local needsAuraReapply = auraOwned == true
    if needsAuraReapply and not cooldown.OGMThemeReapplyQueued then
        cooldown.OGMThemeReapplyQueued = true
        C_Timer.After(0, function()
            cooldown.OGMThemeReapplyQueued = nil
            if active[cooldownID] == cooldown and not cooldown.noCooldownCount and not (Addon.CompatibilityOwnsFrame and Addon:CompatibilityOwnsFrame(cooldown)) then
                local themeName = Addon:GetThemeName(cooldown)
                themers[themeName](cooldown)
                onCooldownSizeChanged(cooldown, cooldown:GetWidth())
            end
        end)
    end
end

-- TP AurasWidget native Set(start,duration) bridge. The engine already owns
-- themed text and action-bar timers; register only the TP aura cooldown.
function Addon:StyleThreatPlatesAuraCooldown(cd)
    if _G.OmniCC_GODMODE_CooldownsOnly ~= true or not cd or not threatPlatesOwnsCooldown(cd) then return end
    -- TP sets noCooldownCount on the cooldown at creation. Clear it only
    -- for its confirmed aura frames in CD Only, otherwise engine exits early.
    suppressTPWhiteText(cd)
    -- The legacy overlay entrypoint was still registering its own text here,
    -- despite the SetCooldown hooks suppressing that renderer. Keep the
    -- original TP icon and remove any existing overlay for this cooldown.
    local label = tpOverlayFrames[cd]
    if label then label:Hide(); tpOverlayFrames[cd] = nil end
end

-- Forever native Blizzard settings bridge.
-- Keep Blizzard as the persistence owner whenever Forever exposes a native
-- setting for a GODMODE control.  This deliberately does not exist in the
-- Midnight branch.
local function OGM_SetNativeCVar(name, value)
    if not name then return false end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    local v = value and "1" or "0"
    if C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, name, v)
        if ok then return true end
    end
    if SetCVar then
        local ok = pcall(SetCVar, name, v)
        if ok then return true end
    end
    return false
end

local function OGM_GetNativeCVarBool(name)
    local value
    if C_CVar and C_CVar.GetCVar then
        local ok, result = pcall(C_CVar.GetCVar, name)
        if ok then value = result end
    elseif GetCVar then
        local ok, result = pcall(GetCVar, name)
        if ok then value = result end
    end
    return tostring(value) == "1"
end

function Addon:SetBlizzardCountdownNumbers(enabled)
    self._foreverNativeCountdownWanted = enabled and true or false
    if OGM_SetNativeCVar('countdownForCooldowns', enabled) then
        self._foreverNativeCountdownPending = nil
        return true
    end
    self._foreverNativeCountdownPending = true
    return false
end

function Addon:GetBlizzardCountdownNumbers()
    return OGM_GetNativeCVarBool('countdownForCooldowns')
end

-- Public Forever-only native bridge used by the BLIZZARD settings tab.
-- It intentionally exposes only CVars that the client itself reports as present.
function Addon:GetForeverNativeCVar(name)
    if not name then return nil end
    local value
    if C_CVar and C_CVar.GetCVar then
        local ok, result = pcall(C_CVar.GetCVar, name)
        if ok then value = result end
    elseif GetCVar then
        local ok, result = pcall(GetCVar, name)
        if ok then value = result end
    end
    return value
end

function Addon:HasForeverNativeCVar(name)
    return self:GetForeverNativeCVar(name) ~= nil
end

function Addon:SetForeverNativeCVarBool(name, enabled)
    return OGM_SetNativeCVar(name, enabled)
end

function Addon:GetForeverNativeCVarBool(name)
    return OGM_GetNativeCVarBool(name)
end

function Addon:SyncForeverNativeSettings()
    if not self.db or not self.db.profile then return end
    local enabled = false
    for _, rule in self:IterateRules() do
        if self:IsRuleEnabled(rule) then enabled = true; break end
    end
    self:SetBlizzardCountdownNumbers(enabled)
end

local OGMNativeBridgeEvents = CreateFrame('Frame')
OGMNativeBridgeEvents:RegisterEvent('PLAYER_LOGIN')
OGMNativeBridgeEvents:RegisterEvent('PLAYER_REGEN_ENABLED')
OGMNativeBridgeEvents:SetScript('OnEvent', function(_, event)
    if Addon.db then
        if event == 'PLAYER_LOGIN' or Addon._foreverNativeCountdownPending then
            Addon:SyncForeverNativeSettings()
        end
    end
end)

function Addon:OnLoad()
    -- initialize db
    local db = LibStub('AceDB-3.0'):New(DB_NAME, self:GetDBDefaults(), DEFAULT)

    db.RegisterCallback(self, 'OnProfileChanged', 'Refresh')
    db.RegisterCallback(self, 'OnProfileCopied', 'Refresh')
    db.RegisterCallback(self, 'OnProfileReset', 'Refresh')

    self.db = db
    -- Add a dedicated, editable Auto-Fit theme to existing and fresh profiles.
    -- Never overwrite a user's customized Auto-Fit appearance.
    if type(db.profile.themes) == 'table' and not db.profile.themes.godmode_autofit then
        local source = db.profile.themes.default or {}
        local copy = CopyTable and CopyTable(source) or {}
        copy.enabled = true
        copy.displayName = 'Auto-Fit Cooldown Text'
        copy.themeText = true
        copy.drawText = 'always'
        copy.autoFitText = true
        copy.scaleText = false
        copy.minScale = 0
        copy.fontSize = 13
        copy.abbrevThreshold = 0
        -- Independent, editable Auto-Fit duration colors (5s / 60s / 1h / >1h).
        copy.textColors = {
            { threshold = 5, color = 'FF6347FF' },
            { threshold = 60, color = '40E0D0FF' },
            { threshold = 3600, color = '00B7DFFF' },
            { threshold = 315360000, color = 'DDEEEEFF' },
        }
        copy.defaultTextColor = 'DDEEEEFF'
        db.profile.themes.godmode_autofit = copy
    end
    -- Existing Auto-Fit themes from the first 1.4.2 builds may have inherited
    -- only the two-color default. Upgrade only that exact untouched palette.
    -- Never replace a user's edited duration colors.
    local af = type(db.profile.themes) == 'table' and db.profile.themes.godmode_autofit
    -- Auto-Fit must never emit wide mm:ss strings on action buttons.
    -- Keep all other user theme choices and SavedVariables intact.
    -- Respect saved Auto-Fit formatting; defaults already define new profiles.
    -- Never rewrite an existing theme property during startup.
    if type(af) == 'table' and type(af.textColors) == 'table' and #af.textColors == 1
        and af.textColors[1].threshold == 300 and af.textColors[1].color == '244BFFFF' then
        af.textColors = {
            { threshold = 5, color = 'FF6347FF' },
            { threshold = 60, color = '40E0D0FF' },
            { threshold = 3600, color = '00B7DFFF' },
            { threshold = 315360000, color = 'DDEEEEFF' },
        }
        af.defaultTextColor = 'DDEEEEFF'
    end

    -- Four explicit editable duration rows, including the >1 hour band.
    -- Only migrate the exact GODMODE default; preserve user-customized palettes.
    if type(af) == 'table' and type(af.textColors) == 'table' and #af.textColors == 3
        and af.textColors[1].threshold == 5 and af.textColors[1].color == 'FF6347FF'
        and af.textColors[2].threshold == 60 and af.textColors[2].color == '40E0D0FF'
        and af.textColors[3].threshold == 3600 and af.textColors[3].color == '00B7DFFF'
        and af.defaultTextColor == 'DDEEEEFF' then
        af.textColors[4] = { threshold = 315360000, color = 'DDEEEEFF' }
    end

    -- One-time repair of legacy Auto-Fit palettes created by 1.4.2.
    -- This is restricted to the dedicated Auto-Fit theme. Subsequent user
    -- color edits remain untouched on every login and profile reload.
    -- Preserve existing saved Auto-Fit colors; never replace user palettes.
    if type(af) == 'table' and not af.ogmAutoFitPaletteV2 then
        af.ogmAutoFitPaletteV2 = true
    end

    -- Forever only: an Auto-Fit palette inherited from an older blank theme
    -- displayed just "All durations". Seed the three normal color bands,
    -- leaving the fourth (above one hour) as the editable default color.
    -- Never overwrite nonempty user-defined threshold lists.
    if type(af) == 'table' and (type(af.textColors) ~= 'table' or #af.textColors == 0) then
        af.textColors = {
            { threshold = 5, color = 'FF6347FF' },
            { threshold = 60, color = '40E0D0FF' },
            { threshold = 3600, color = '00DDAAFF' },
        }
        -- Preserve an explicitly customized default color.
        if not af.defaultTextColor or af.defaultTextColor == 'FFFFFFFF' then
            af.defaultTextColor = 'FFFFFFFF'
        end
    end
    -- The earlier four-entry factory palette created a redundant years-long
    -- threshold instead of the intended "Above 1 hour(s)" default row.
    if type(af) == 'table' and type(af.textColors) == 'table' and #af.textColors == 4
        and af.textColors[1].threshold == 5 and af.textColors[1].color == 'FF6347FF'
        and af.textColors[2].threshold == 60 and af.textColors[2].color == '40E0D0FF'
        and af.textColors[3].threshold == 3600 and af.textColors[3].color == '00B7DFFF'
        and af.textColors[4].threshold == 315360000 and af.textColors[4].color == 'DDEEEEFF' then
        table.remove(af.textColors, 4)
    end

    -- Mirror the master cooldown-number state into Blizzard's own persistent
    -- countdownForCooldowns setting. Blizzard then owns the on/off persistence.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() if self.db then self:SyncForeverNativeSettings() end end)
    end

    -- TargetFrame's custom duration bridge can receive PLAYER_LOGIN before this
    -- AceDB initialization has completed on /reload. Reapply its typography only
    -- after the real saved profile exists so font size 9 is 9 immediately,
    -- without requiring a Thin/Thick toggle to force a manual Refresh.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local bridge = self.ForeverTargetAuraTimers
            if bridge and bridge.Build then pcall(bridge.Build) end
            if bridge and bridge.ApplyTheme then pcall(bridge.ApplyTheme) end
        end)
    end

    -- Legacy migration markers: keep historical profiles untouched. Older
    -- migrations forcibly enabled every rule, changed theme assignments,
    -- removed custom themes and reset offsets on first load. That destroyed
    -- users' saved appearance after updates or profile switches. New profiles
    -- already receive the correct defaults from GetDBDefaults().
    -- Do not stamp migration versions here: leaving the original saved marker
    -- intact avoids concealing what version the profile previously used.

    -- GODMODE settings are standalone; never attach the config loader to Blizzard SettingsPanel.
    self.frame = CreateFrame("Frame")
    self.frame.owner = self

    -- setup hooks
    local CooldownMT = getmetatable(ActionButton1Cooldown).__index

    hooksecurefunc(CooldownMT, 'SetCooldown', onCooldownStart)
    hooksecurefunc(CooldownMT, 'SetCooldownDuration', onCooldownStart)
    hooksecurefunc(CooldownMT, 'SetCooldownFromDurationObject', onCooldownStart)
    hooksecurefunc(CooldownMT, 'SetCooldownFromExpirationTime', onCooldownStart)
    hooksecurefunc(CooldownMT, 'SetCooldownUNIX', onCooldownStart)
    -- Threat Plates may update swipe visibility after applying aura settings.
    -- The native white timer stays suppressed; the overlay is the sole text.
    if type(CooldownMT.SetShownSwipe) == 'function' then
    hooksecurefunc(CooldownMT, 'SetShownSwipe', function(cooldown)
        if isBlizzardExcludedCooldown(cooldown) then return end
        if cooldown and threatPlatesOwnsCooldown(cooldown) then
            cooldown.noCooldownCount = true
            if cooldown.SetHideCountdownNumbers then
                pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
            end
            -- tpOverlayRegister disabled: old separate white-number renderer
        end
    end)
    end
    hooksecurefunc(CooldownMT, 'Clear', onCooldownStop)

    -- setup enforcers (hooks that apply our settings)
    local function lock(func)
        local running = false
        return function(cooldown, ...)
            if isBlizzardExcludedCooldown(cooldown) then return end
            if not running then
                running = true
                func(cooldown, ...)
                running = false
            end
        end
    end

    -- Countdown geometry has exactly one owner: CreateThemer/ApplyCountdownTextPosition
    -- in forever/engine/themer.lua.  Do not hook SetCountdownFormatter here; that
    -- created a formatter -> anchor -> stabilizer feedback path and allowed a
    -- later formatter refresh to fight the selected 9-point anchor.

    local function enforceCooldownSetting(method, setting)
        hooksecurefunc(CooldownMT, method, lock(function(cooldown, value)
            -- Live Theme Preview is an isolated renderer. Never let the normal
            -- cooldown engine force Action Bars settings back onto its samples.
            if cooldown and cooldown.OGMThemePreview then return end
            local theme = getTheme(cooldown)
            if not (theme and theme.themeCooldown) then return end

            if theme[setting] == "always" then
                if issecretvalue(value) or not value then
                    cooldown[method](cooldown, true)
                end
            elseif theme[setting] == "never" then
                if issecretvalue(value) or value then
                    cooldown[method](cooldown, false)
                end
            end
        end))
    end

    enforceCooldownSetting('SetDrawBling', 'drawBling')
    enforceCooldownSetting('SetDrawEdge', 'drawEdge')
    enforceCooldownSetting('SetDrawSwipe', 'drawSwipe')
    enforceCooldownSetting('SetReverse', 'reverse')

    hooksecurefunc(CooldownMT, 'SetSwipeColor', lock(function(cooldown, r, g, b, a)
        -- Preview owns its swipe color directly and must update live.
        if cooldown and cooldown.OGMThemePreview then return end
        local theme = getTheme(cooldown)
        if not (theme and theme.themeCooldown and theme.themeSwipeColor) then
            return
        end

        local cR, cG, cB, cA = Addon.HexToRGBA(theme.swipeColor)
        if issecretvalue(r) or not (r == cR and g == cG and b == cB and a == cA) then
            cooldown:SetSwipeColor(cR, cG, cB, cA)
        end
    end))

    hooksecurefunc(CooldownMT, 'SetHideCountdownNumbers', lock(function(cooldown, hide)
        -- Blizzard can restore native text after SetCooldown. Keep the rank
        -- badge silent without changing any other cooldown or theme setting.
        if cooldown and cooldown._ogmPvPRankTimerSuppressed then
            if issecretvalue(hide) or hide ~= true then
                cooldown:SetHideCountdownNumbers(true)
            end
            return
        end
        -- GODMODE Theme Live Preview owns its single sample timer text.
        -- Never let the normal cooldown/theme hook re-enable Blizzard's native
        -- countdown number on preview cooldowns, otherwise two timers appear.
        if cooldown and cooldown.OGMThemePreview then
            if issecretvalue(hide) or not hide then cooldown:SetHideCountdownNumbers(true) end
            return
        end
        if cooldown and cooldown.noOCC then
            if cooldown.OGMPlayerCCNativeCountdown then return end
            if issecretvalue(hide) or not hide then cooldown:SetHideCountdownNumbers(true) end
            return
        end
        if threatPlatesOwnsCooldown(cooldown) then
            -- TP initially hides Blizzard's native number. In Cooldowns Only,
            -- GODMODE themes that SAME FontString; do not let TP's hide flag
            -- or generic compatibility ownership suppress it.
            cooldown.noCooldownCount = true
            if not issecretvalue(hide) and hide == false then
                cooldown:SetHideCountdownNumbers(true)
            end
            return
        end
        if Addon.CompatibilityOwnsFrame and Addon:CompatibilityOwnsFrame(cooldown) then return end
        -- TargetFrame's native cooldown numbers must stay OFF permanently.
        -- GODMODE renders one authoritative duration through SetDurationText
        -- beneath the real aura button. Blizzard can reissue false here during
        -- periodic aura refreshes; immediately force it back to hidden so the
        -- display cannot jump between Blizzard and GODMODE positions.
        if cooldown.OGMTargetAuraNativeSuppressed or cooldown.OGMNameplateBoundDuration then
            if issecretvalue(hide) or not hide then
                cooldown:SetHideCountdownNumbers(true)
            end
            return
        end

        -- Forever nameplate aura cooldowns are protected Blizzard frames.
        -- Their native countdown visibility must not be toggled back and forth by
        -- GODMODE every time Blizzard refreshes the aura. We theme the existing
        -- FontString, but leave its hide/show lifecycle to Blizzard.
        if isGodmodeNameplateCooldown(cooldown) then return end

        local theme = getTheme(cooldown)
        if not (theme and theme.themeText) then return end

        if theme.drawText == "always" then
            if issecretvalue(hide) or hide then
                cooldown:SetHideCountdownNumbers(false)
            end
        elseif theme.drawText == "never" then
            if issecretvalue(hide) or not hide then
                cooldown:SetHideCountdownNumbers(true)
            end
        end
    end))

    hooksecurefunc('CooldownFrame_SetDisplayAsPercentage', function(cooldown)
        if cooldown and cooldown._ogmPvPRankTimerSuppressed then
            cooldown.noCooldownCount = true
            if cooldown.SetHideCountdownNumbers then
                pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
            end
            return
        end
        if isBlizzardExcludedCooldown(cooldown) then return end
        -- TP icon countdowns use GODMODE's independent text only. Blizzard's
        -- percentage formatter can run after SetCooldown and must not restore
        -- its oversized native white number.
        if cooldown and threatPlatesOwnsCooldown(cooldown) then
            cooldown.noCooldownCount = true
            if cooldown.SetHideCountdownNumbers then
                pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
            end
            -- tpOverlayRegister disabled: old separate white-number renderer
            return
        end
        if cooldown and cooldown.noOCC then
            cooldown.noCooldownCount = true
            if not cooldown.OGMPlayerCCNativeCountdown and cooldown.SetHideCountdownNumbers then
                pcall(cooldown.SetHideCountdownNumbers,cooldown,true)
            end
            return
        end
        if Addon.CompatibilityOwnsFrame and Addon:CompatibilityOwnsFrame(cooldown) then return end
        -- Same no-blink ownership rule validated on the MoP build: a late
        -- Blizzard/addon percentage refresh cannot steal a GODMODE-owned scope.
        if Addon.GodmodeHardOwnsFrame and Addon:GodmodeHardOwnsFrame(cooldown) then
            if cooldown.OGMNameplateBoundDuration then
                cooldown.noCooldownCount = true
                if cooldown.SetHideCountdownNumbers then pcall(cooldown.SetHideCountdownNumbers,cooldown,true) end
                return
            end
            cooldown.noCooldownCount = nil
            if cooldown.SetHideCountdownNumbers and not cooldown.OGMTargetAuraNativeSuppressed and not isGodmodeNameplateCooldown(cooldown) then
                pcall(cooldown.SetHideCountdownNumbers,cooldown,false)
            end
            return
        end
        if cooldown.noCooldownCount then return end
        cooldown.noCooldownCount = true
        cooldown:SetHideCountdownNumbers(true)
    end)

    -- setup launcher commands
    local function showOptionsFrame()
        local inCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat('player'))
        if inCombat then
            if Addon.ForeverNameplates and Addon.ForeverNameplates.ShowCombatFullPanel then
                Addon.ForeverNameplates.ShowCombatFullPanel()
                return true
            elseif Addon.ForeverNameplates and Addon.ForeverNameplates.ShowQuickPanel then
                Addon.ForeverNameplates.ShowQuickPanel()
                return true
            end
            return false
        end

        local loaded, reason = C_AddOns.LoadAddOn(AddonName .. '_Config')
        if not loaded and not C_AddOns.IsAddOnLoaded(AddonName .. '_Config') then
            print('|cffff5555OmniCC GODMODE:|r unable to load settings (' .. tostring(reason or 'unknown') .. ').')
            return false
        end

        local function openNow()
            if Addon.OpenOptions then
                Addon:OpenOptions()
            elseif _G.OmniCC_GODMODE and _G.OmniCC_GODMODE.OpenOptions then
                _G.OmniCC_GODMODE:OpenOptions()
            end
        end

        if C_Timer and C_Timer.After then C_Timer.After(0, openNow) else openNow() end
        return true
    end

    -- GODMODE ESC button: fit dynamically into the live gap between Macros
    -- and Log Out. Blizzard can reposition these buttons whenever the menu
    -- reopens, so never rely on a one-time fixed pixel offset.
    local ogmGameMenuButton
    local function positionGodmodeGameMenuButton()
        local menu = _G.GameMenuFrame
        if _G.OmniCC_GODMODE_ShowGameMenuButton == false then
            if ogmGameMenuButton then ogmGameMenuButton:Hide() end
            return
        end
        if not menu or not menu:IsShown() or (InCombatLockdown and InCombatLockdown()) then return end
        local macros = _G.GameMenuButtonMacros
        local logout = _G.GameMenuButtonLogout
        if not macros or not logout then
            for _, child in ipairs({menu:GetChildren()}) do
                if child.GetText and child ~= ogmGameMenuButton then
                    local label = child:GetText()
                    if not macros and label == (_G.MACROS or 'Macros') then macros = child end
                    if not logout and (label == (_G.LOG_OUT or 'Log Out') or label == 'Log Out') then logout = child end
                end
            end
        end
        if not macros or not logout then return end
        if not ogmGameMenuButton then
            local button = CreateFrame('Button', 'OmniCCGODMODEGameMenuButton', menu, 'GameMenuButtonTemplate')
            button:SetText('GODMODE')
            local fontString = button.GetFontString and button:GetFontString()
            if fontString then fontString:SetTextColor(1, 0.82, 0.22, 1) end
            button:SetScript('OnClick', function()
                if _G.HideUIPanel then HideUIPanel(menu) else menu:Hide() end
                showOptionsFrame()
            end)
            ogmGameMenuButton = button
            menu._ogmGameMenuButton = button
        end
        local scale = menu:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        local top = macros:GetBottom()
        local bottom = logout:GetTop()
        if not top or not bottom then return end
        local gap = (top - bottom) * scale
        -- Fit between Blizzard's real buttons. Never cover Macros or Log Out.
        if gap < 13 then ogmGameMenuButton:Hide(); return end
        local buttonHeight = math.min(24, gap - 6)
        ogmGameMenuButton:SetSize(macros:GetWidth(), buttonHeight / scale)
        ogmGameMenuButton:ClearAllPoints()
        ogmGameMenuButton:SetPoint('TOP', macros, 'BOTTOM', 0, -3 / scale)
        ogmGameMenuButton:Show()
    end
    if _G.GameMenuFrame then
        _G.GameMenuFrame:HookScript('OnShow', function()
            -- Blizzard's menu layout can finish after OnShow. Recalculate
            -- after that layout instead of accumulating anchor changes.
            positionGodmodeGameMenuButton()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, positionGodmodeGameMenuButton)
            end
        end)
        if _G.GameMenuFrame:IsShown() then positionGodmodeGameMenuButton() end
    end

    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon{
            text = C_AddOns.GetAddOnMetadata(AddonName, "Title"),
            icon = C_AddOns.GetAddOnMetadata(AddonName, "IconTexture"),
            func = showOptionsFrame,
        }
    end

    -- setup slash commands
    SlashCmdList['OMNICC_GODMODE'] = function(msg)
        local cmd = msg and msg:lower():trim()
        local action, frameName = cmd:match("^(exclude)%s+([%w_]+)$")
        if not action then action, frameName = cmd:match("^(include)%s+([%w_]+)$") end
        if action then
            db.profile.godmodeExcludedFrames = db.profile.godmodeExcludedFrames or {}
            if frameName == "ShamanPowerCD1_7" and action == "include" then
                print("|cFFCC99FFOmniCC GODMODE:|r ShamanPowerCD1_7 is excluded by default to prevent an invalid timer.")
            else
                db.profile.godmodeExcludedFrames[frameName] = (action == "exclude") or nil
                print("|cFFCC99FFOmniCC GODMODE:|r " .. frameName .. (action == "exclude" and " excluded" or " included") .. ". /reload to apply to existing timers.")
            end
            return
        elseif cmd == "exclusions" then
            print("|cFFCC99FFOmniCC GODMODE:|r Default excluded: ShamanPowerCD1_7")
            for name, enabled in pairs(db.profile.godmodeExcludedFrames or {}) do
                if enabled then print(" - " .. name) end
            end
            print("Commands: /ogm exclude FrameName | /ogm include FrameName | /ogm exclusions")
            return
        end
        if cmd == "reset" then
            db:ResetProfile()
        elseif cmd == "version" then
            local version = C_AddOns.GetAddOnMetadata(AddonName, "Version")
            print("|cFFCC99FF" .. AddonName .. "|r " .. (version or UNKNOWN))
        else
            showOptionsFrame()
        end
    end

    SLASH_OMNICC_GODMODE1 = '/ogm'
    SLASH_OMNICC_GODMODE2 = '/omniccgm'
    SLASH_OMNICC_GODMODE3 = '/omniccgodmode'
end

-- note that colors are in fully qualified web color format #RRGGBBAA
function Addon:GetDBDefaults()
    return {
        profile = {
            themes = {
                ['**'] = {
                    -- global theme toggle
                    enabled = true,

                    -- basic toggles for styling groups
                    themeText = true,
                    themeCooldown = true,

                    -- draw states
                    -- "default" | "always" | "never"
                    drawBling = "default",
                    drawEdge = "default",
                    drawSwipe = "default",
                    drawText = "always",
                    reverse = "default",

                    -- cooldown text font settings
                    -- font is a LSM font ID
                    font = "Friz Quadrata TT",
                    fontFlags = 'OUTLINE',
                    -- setting a font size to zero will just let the ui handle sizing
                    fontSize = 18,

                    -- text positioning
                    point = "CENTER",
                    -- GODMODE Forever default text placement: 3px right, 0px vertical.
                    offsetX = 3,
                    offsetY = 0,

                    -- text shadow
                    shadowColor = "FFFFFF00",
                    shadowX = 0,
                    shadowY = 0,

                    -- text scaling and visibility
                    scaleText = true,
                    minScale = 0.5,

                    -- how long a cooldown must be in order to display text
                    minDuration = 2,

                    -- tenths duration (0.1)
                    tenthsThreshold = 0,

                    -- minutes format (1m)
                    minutesThreshold = 60,

                    -- mm:ss format (12:00)
                    abbrevThreshold = 90,

                    -- hours format (4h)
                    hoursThreshold = 3600,

                    -- days format (7d)
                    daysThreshold = 86400,

                    -- weeks format (1w)
                    weeksThreshold = 604800,

                    -- key of Enum.NumericRuleFormatRounding
                    roundingMode = "Nearest",

                    -- show zero for rounding modes that would show empty at threshold 0
                    showZero = false,

                    -- array of {threshold, color} entries
                    -- thresholds are specified in seconds and represent the
                    -- duration at which we want to start applying a color
                    textColors = {},

                    -- color for all durations (when no thresholds defined)
                    defaultTextColor = "FFFFFFFF",

                    -- swipe color
                    themeSwipeColor = false,
                    swipeColor = "000000CC",
                },

                -- default styling with conditional colors
                default = {
                    textColors = {
                        -- soon (0 - 5s)
                        { threshold = 5,    color = "FF6347FF" },
                        -- seconds (5 - 60s)
                        { threshold = 60,   color = "FFFF00FF" },
                        -- minutes (60 - 3600s)
                        { threshold = 3600, color = "FFFFFFFF" },
                    },

                    defaultTextColor = "AAAAAAFF"
                },

                nameplates = {
                    -- Explicit Forever fresh-install cooldown appearance.
                    drawSwipe = "never",
                    drawEdge = "always",
                    drawBling = "always",
                    reverse = "never",
                    fontSize = 15,
                    drawText = "always",
                    minDuration = 0,
                    abbrevThreshold = 0,
                    scaleText = false,
                    minScale = 0,
                    fontFlags = "OUTLINE",
                    textColors = {
                        { threshold = 5, color = "FF6347FF" },
                        { threshold = 60, color = "40E0D0FF" },
                        { threshold = 3600, color = "DB7093FF" },
                    },
                    defaultTextColor = "FFFFFFFF"
                },

                -- Unified GODMODE unit-aura appearance. SELF + TARGET Buffs/Debuffs
                -- use this one visible theme instead of the removed hidden split themes.
                auras = {
                    fontSize = 10,
                    drawText = "always",
                    minDuration = 0,
                    abbrevThreshold = 0,
                    scaleText = false,
                    minScale = 0,
                    fontFlags = "OUTLINE",
                    point = "BOTTOM",
                    offsetX = 0,
                    offsetY = 0,
                    textColors = {
                        { threshold = 5, color = "FF6347FF" },
                        { threshold = 60, color = "FFFF00FF" },
                        { threshold = 3600, color = "FFFFFFFF" },
                    },
                    defaultTextColor = "FFFFFFFF"
                },

                omnicc = {
                    fontSize = 18,
                    drawText = "always",
                    minDuration = 2,
                    abbrevThreshold = 0,
                    scaleText = true,
                    minScale = 0.5,

                    textColors = {
                        -- soon (0 - 5s)
                        { threshold = 5,    color = "FF6347FF" },
                        -- seconds (5 - 60s)
                        { threshold = 60,   color = "FFFF00FF" },
                        -- minutes (60 - 3600s)
                        { threshold = 3600, color = "FFFFFFFF" },
                    },

                    defaultTextColor = "AAAAAAFF"
                },

                none = {
                    enabled = false
                }
            },

            -- rule to theme mapping
            rules = {
                ['*'] = {
                    enabled = true,
                    theme = "default"
                },
                blizzard_nameplates = {
                    enabled = true,
                    theme = "nameplates"
                },
                godmode_nameplate_aura = {
                    enabled = true,
                    theme = "nameplates"
                },
            },

            godmodeDefaultsVersion = 7
        }
    }
end

function Addon:GetThemeName(cooldown)
    -- Narrow TPerl handoff: reuse the existing aura theme, never rewrite rules.
    -- The marker is assigned only by TPerl to its own aura cooldown objects.
    if cooldown and cooldown._ogmTPerlAuraKind and
        _G.TPerl_GODMODE_AuraOwnership and
        _G.TPerl_GODMODE_AuraOwnership[cooldown._ogmTPerlAuraKind == 'debuff' and 'debuffs' or 'buffs'] == true then
        return 'auras'
    end
    -- Effective rule override only: never mutate profile.rules.
    local p = self.db and self.db.profile
    if p and p.godmodeAutoFitEnabled
        and not threatPlatesOwnsCooldown(cooldown)
        and not (_G.OmniCC_GODMODE_CooldownsOnly == true and isNameplateDescendant(cooldown))
        and not (self.CompatibilityOwnsFrame and self:CompatibilityOwnsFrame(cooldown))
        and not (cooldown and cooldown.noOCC) then
        return 'godmode_autofit'
    end
    -- Virtual silent theme for nameplate cooldowns in Cooldowns Only.
    -- Do not touch the persistent Action Bars theme or real action buttons.
    if cooldownsOnlySilentNameplate(cooldown) then return 'ogm_tp_silent' end
    if isNameplateDescendant(cooldown) then return 'nameplates' end
    -- Cooldowns Only: Threat Plates owns the aura icon, while GODMODE owns
    -- its existing cooldown's text. Route this specific native cooldown to
    -- the persistent Nameplates theme, not the Default/Action Bars theme.
    -- Never alter third-party frames when the mode is disabled.
    if _G.OmniCC_GODMODE_CooldownsOnly == true and threatPlatesOwnsCooldown(cooldown) then
        return "nameplates"
    end
    -- GODMODE custom Forever aura rows are explicitly marked by
    -- forever_nameplate_auras.lua. Force them through the single persistent
    -- Nameplates theme so fresh/recast auras cannot fall back to Default.
    if isGodmodeNameplateCooldown(cooldown) then
        return "nameplates"
    end

    for _, rule in self:IterateActiveRules() do
        if rule.match(cooldown) then
            -- AceDB can strip the all-default rules table during logout.
            local profile = self.db and self.db.profile
            local rules = profile and profile.rules
            local settings = rules and rules[rule.id]
            return settings and settings.theme or "default"
        end
    end

    return "default"
end

function Addon:IsRuleEnabled(rule)
    -- A third-party cooldown can reach the rule matcher before the saved
    -- configuration entry for that rule exists. Preserve the rule's built-in
    -- default instead of indexing a nil config table.
    if type(rule) ~= "table" then
        return true
    end

    local profile = self.db and self.db.profile
    local rules = profile and profile.rules
    local config = rules and rules[rule.id]

    if type(config) == "table" and config.enabled ~= nil then
        return config.enabled
    end

    return rule.enabled == true
end
-- Midnight-equivalent native action-button styling, isolated to Forever's API adapter.
-- Only native Blizzard cooldown FontStrings are styled; no duplicate countdown is created.
OGMIsNativeActionButtonCooldown = function(cooldown)
    if not cooldown or not cooldown.GetParent then return false end
    local parent = cooldown:GetParent()
    if not parent or not parent.GetName then return false end
    local ok, name = pcall(parent.GetName, parent)
    return ok and type(name) == 'string' and (
        name:match('^ActionButton%d+$') or name:match('^MultiBar[%w_]+Button%d+$')
        or name:match('^OverrideActionBarButton%d+$') or name:match('^PetActionButton%d+$')
        or name:match('^StanceButton%d+$')) ~= nil
end
-- Match Midnight native action countdown label geometry without reading protected text.
-- This runs only on theme refresh / action cooldown creation, never on every frame.
local function OGMConnectActionFormatFit(cooldown, label)
    if not label or not OGMIsNativeActionButtonCooldown(cooldown) then return end
    if label.SetWordWrap then pcall(label.SetWordWrap, label, false) end
    if label.SetNonSpaceWrap then pcall(label.SetNonSpaceWrap, label, false) end
    if label.SetJustifyH then pcall(label.SetJustifyH, label, 'CENTER') end
    if label.SetWidth then pcall(label.SetWidth, label, 0) end
end
function Addon:StyleLiveActionButton(cooldown)
        if not ogmActionControlEnabled(cooldown) then
            ogmReleaseActionStyle(cooldown)
            return
        end
    if not OGMIsNativeActionButtonCooldown(cooldown) then return end
    if self.CompatibilityOwnsFrame and self:CompatibilityOwnsFrame(cooldown) then return end
    local profile = self.db and self.db.profile
    local themes = profile and profile.themes
    local config = themes and themes[(profile.godmodeAutoFitEnabled and 'godmode_autofit') or 'default']
    if not (config and config.enabled) then return end
    local fontPath = STANDARD_TEXT_FONT
    if config.font and LibStub then
        local media = LibStub('LibSharedMedia-3.0', true)
        fontPath = (media and media:Fetch('font', config.font)) or fontPath
    end
    local fontSize = math.max(1, math.min(25, tonumber(config.fontSize) or 12))
    if self.CreateCountdownFormatter and cooldown.SetCountdownFormatter then
        local ok, formatter = pcall(self.CreateCountdownFormatter, self, config)
        if ok and formatter then pcall(cooldown.SetCountdownFormatter, cooldown, formatter) end
    end
    local ok, label = pcall(cooldown.GetCountdownFontString, cooldown)
    if ok and label and config.themeText then
        pcall(label.SetScale, label, 1)
        pcall(label.SetFont, label, fontPath, fontSize, config.fontFlags)
        OGMConnectActionFormatFit(cooldown, label)
        if config.shadowColor and self.HexToRGBA then
            local r,g,b,a = self.HexToRGBA(config.shadowColor)
            if r then pcall(label.SetShadowColor, label, r,g,b,a) end
            pcall(label.SetShadowOffset, label, tonumber(config.shadowX) or 0, tonumber(config.shadowY) or 0)
        end
    end
    if config.themeCooldown then
        local appearance = {
            {'SetDrawSwipe', config.drawSwipe}, {'SetDrawEdge', config.drawEdge},
            {'SetDrawBling', config.drawBling}, {'SetReverse', config.reverse},
        }
        for i = 1, #appearance do
            local method, mode = appearance[i][1], appearance[i][2]
            if cooldown[method] and (mode == 'always' or mode == 'never') then
                pcall(cooldown[method], cooldown, mode == 'always')
            end
        end
        if config.themeSwipeColor and config.swipeColor and self.HexToRGBA and cooldown.SetSwipeColor then
            local r,g,b,a = self.HexToRGBA(config.swipeColor)
            if r then pcall(cooldown.SetSwipeColor, cooldown, r,g,b,a or 1) end
        end
    end
    if config.themeText and (config.drawText == 'always' or config.drawText == 'never') then
        local hidden = config.drawText == 'never'
        if cooldown.SetHideCountdownNumbers then
            pcall(cooldown.SetHideCountdownNumbers, cooldown, hidden)
        end
        if ok and label then pcall(label.SetAlpha, label, hidden and 0 or 1) end
    end
    cooldown._ogmStaticStyleGeneration = OGMHotPathGeneration
    cooldown._ogmThemeGeneration = OGMHotPathGeneration
    cooldown._ogmThemeName = 'default'
end
local function OGMStyleForeverActionButton(cooldown)
    Addon:StyleLiveActionButton(cooldown)
end

-- throttle refresh since it can be called a bunch by the config ui
do
    local refreshing
    local function restyleCooldowns()
        wipe(themers)

        for _, cooldown in pairs(active) do
            local isAura = Addon.ForeverAuraText and Addon.ForeverAuraText.Classify
                and Addon.ForeverAuraText:Classify(cooldown)
            local themeName = Addon:GetThemeName(cooldown)
            local func = themers[themeName]

            -- Dedicated SELF/TARGET/minimap aura controls own their text.
            -- Never apply the global Theme on top of them.
            if not isAura and ogmActionControlEnabled(cooldown) and ogmSurfaceAllowed(cooldown) and func then
                func(cooldown)
            elseif not ogmSurfaceAllowed(cooldown) then
                ogmReleaseSurfaceStyle(cooldown)
            elseif not ogmActionControlEnabled(cooldown) then
                ogmReleaseActionStyle(cooldown)
            end
            if not isAura and ogmActionControlEnabled(cooldown) and ogmSurfaceAllowed(cooldown) then OGMStyleForeverActionButton(cooldown) end
            -- Fit after the theme applies its configured font size.
            onCooldownSizeChanged(cooldown, cooldown:GetWidth())
            styleTPNameplateText(cooldown)
            if isGodmodeNameplateCooldown(cooldown) then
                stabilizeNameplateCountdownText(cooldown)
            end
            if Addon.ForeverAuraText and Addon.ForeverAuraText.Apply then
                Addon.ForeverAuraText:Apply(cooldown)
            end
        end

        refreshing = false
    end

    -- Midnight parity: a second, coalesced action-only pass follows Blizzard's
    -- cooldown layout update. The first pass remains immediate for live UI.
    local actionStyleQueued = false
    local function restyleLiveActionButtons()
        actionStyleQueued = false
        for _, cooldown in pairs(active) do
            OGMStyleForeverActionButton(cooldown)
        end
    end

    function Addon:Refresh()
        OGMHotPathGeneration = OGMHotPathGeneration + 1
        if not refreshing then
            refreshing = true
            C_Timer.After(0, restyleCooldowns)
        end
        if not actionStyleQueued then
            actionStyleQueued = true
            C_Timer.After(0.08, restyleLiveActionButtons)
        end
    end
end

EventUtil.ContinueOnAddOnLoaded(AddonName, function() Addon:OnLoad() end)

-- export the addon
_G[AddonName] = Addon
