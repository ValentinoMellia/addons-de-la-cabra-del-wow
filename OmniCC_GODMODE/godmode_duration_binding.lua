local _, Addon = ...

-- GODMODE Countdown Engine V2 (Midnight / Forever only).
-- Uses Blizzard's duration-text binding so restricted aura remaining-time data
-- never has to be read by addon Lua. Legacy clients never load this file.
local Engine = {}
Addon.GODMODEDurationBinding = Engine

local cachedFormatter

function Engine:IsSupported()
    return C_AuraContainerUtil
        and C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions
        and C_StringUtil
        and C_StringUtil.CreateNumericRuleFormatter
        and Enum
        and Enum.NumericRuleFormatRounding
end

local function formatter()
    if cachedFormatter then return cachedFormatter end
    if not Engine:IsSupported() then return nil end

    -- API shape has changed between 12.x builds. Never let formatter creation
    -- break aura rendering: probe/build it behind pcall and fall back to
    -- Blizzard's plain duration binding when a build rejects any rule.
    local ok, f = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not ok or not f or type(f.AddBreakpoint) ~= "function" then return nil end
    local rounding = Enum.NumericRuleFormatRounding
    ok = pcall(function()
        f:AddBreakpoint({ threshold = 0, step = 1, rounding = rounding.Up, format = '%d' })
        f:AddBreakpoint({ threshold = 61, step = 1, rounding = rounding.Down, min = 1,
            format = '%dm', components = { { div = 60, rounding = rounding.Up } } })
        f:AddBreakpoint({ threshold = 5401, step = 1, rounding = rounding.Down, min = 1,
            format = '%dh', components = { { div = 3600, rounding = rounding.Up } } })
    end)
    if not ok then return nil end
    cachedFormatter = f
    return f
end

local function themeFormatter(themeID)
    local profile = Addon and Addon.db and Addon.db.profile
    local themes = profile and profile.themes
    local actionTheme = themes and themes[((themeID == "auras") and "auras") or ((profile and profile.godmodeAutoFitEnabled and "godmode_autofit") or themeID or "default")]
    if not actionTheme or not Addon then return nil, nil end

    local f
    if Addon.CreateCountdownTextFormatter then
        -- Midnight secure aura labels use compact minutes from 60s upward.
        -- Build a transient formatter configuration: never mutate saved themes
        -- or the user's action-bar MM:SS preference.
        local auraConfig = {}
        for k, v in pairs(actionTheme) do auraConfig[k] = v end
        -- Forever 1.60.1 SELF/TARGET aura rows must abbreviate minutes as 53m,
        -- never render MM:SS (53:35).  Zero selects the compact-minutes branch
        -- in forever/engine/themer.lua.  Keep Midnight's existing behavior intact.
        if select(4, GetBuildInfo()) == 16001 then
            auraConfig.abbrevThreshold = 0
        else
            auraConfig.abbrevThreshold = 60
        end
        local ok, result = pcall(Addon.CreateCountdownTextFormatter, Addon, auraConfig)
        if ok and result then f = result end
    end
    if not f then f = formatter() end
    return f, actionTheme
end

local function hexColor(value)
    if Addon and Addon.CreateColor then
        local ok, c = pcall(Addon.CreateColor, value)
        if ok and c then return c end
    end
    if type(value) ~= 'string' or not CreateColor then return nil end
    local hex=value:gsub('#','')
    if #hex < 6 then return nil end
    local r=tonumber(hex:sub(1,2),16) or 255
    local g=tonumber(hex:sub(3,4),16) or 255
    local b=tonumber(hex:sub(5,6),16) or 255
    local a=(#hex >= 8 and tonumber(hex:sub(7,8),16)) or 255
    return CreateColor(r/255,g/255,b/255,a/255)
end

-- Build the exact action-bar threshold map as a native DurationText color curve.
-- This is the supported 12.1 / 1.60.1 path for secure aura duration text and is
-- the same mechanism current Plater uses for its secure aura timer coloring.
local function actionBarColorCurve(theme)
    if not theme or not C_CurveUtil or not C_CurveUtil.CreateColorCurve
        or not Enum or not Enum.LuaCurveType then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    if curve.SetType and Enum.LuaCurveType.Step then
        pcall(curve.SetType, curve, Enum.LuaCurveType.Step)
    end

    local entries={}
    if type(theme.textColors)=='table' then
        for i=1,#theme.textColors do
            local e=theme.textColors[i]
            local threshold=type(e)=='table' and tonumber(e.threshold)
            local color=type(e)=='table' and hexColor(e.color)
            if threshold and color then entries[#entries+1]={threshold=threshold,color=color} end
        end
    end
    table.sort(entries,function(a,b) return a.threshold < b.threshold end)

    local defaultColor=hexColor(theme.defaultTextColor or 'FFFFFFFF') or (CreateColor and CreateColor(1,1,1,1))
    if #entries==0 then
        if defaultColor and curve.AddPoint then pcall(curve.AddPoint,curve,0,defaultColor) end
        return curve
    end

    -- OmniCC theme thresholds are END points: first color covers 0..threshold1,
    -- second covers threshold1..threshold2, etc. Convert them to the START points
    -- required by a Step curve, matching themer.lua getColorBreakpoints exactly.
    if curve.AddPoint then
        pcall(curve.AddPoint,curve,0,entries[1].color)
        for i=2,#entries do
            pcall(curve.AddPoint,curve,entries[i-1].threshold,entries[i].color)
        end
        if defaultColor then
            pcall(curve.AddPoint,curve,entries[#entries].threshold,defaultColor)
        end
    end
    return curve
end

function Engine:Bind(button, fontString, opts)
    if not button or not fontString or not button.SetDurationText then return false end

    local f, actionTheme
    local options
    if type(opts) == 'table' and (opts.actionBarColors or opts.themeID) then
        f, actionTheme = themeFormatter((opts and opts.themeID) or "default")
        local curve = actionBarColorCurve(actionTheme)
        options = { textFormatter = f }
        local e = Enum and Enum.DurationTextBindingProperty
        local prop = e and e.RemainingDuration
        if prop == nil then prop = 0 end -- RemainingDuration is enum value 0 on current Midnight/Forever
        if curve then
            options.textColor = { curve = curve, property = prop }
        end
    else
        f = formatter()
        options = { textFormatter = f }
    end

    if f then
        -- 12.1/1.60.1 requires custom aura duration options to be normalized by
        -- AuraContainerUtil before they are attached to an AuraButton.
        if C_AuraContainerUtil and C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions then
            local okProcessed, processed = pcall(C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions, options)
            if okProcessed and processed then options = processed end
        end
        local ok, result = pcall(button.SetDurationText, button, fontString, options)
        if ok and result ~= false then return true end
    end
    -- Compatibility fallback for builds that expose SetDurationText but reject
    -- newer formatter/color options. The aura remains functional, only uncolored.
    return pcall(button.SetDurationText, button, fontString)
end

-- Cooperative TPerl secure-aura bridge: reuse its existing Blizzard DurationText.
-- No new fontstrings, no aura polling, and no changes to GODMODE's own renderers.
_G.OmniCC_GODMODE_BindTPerlDuration = function(button, fontString)
    if not button or not fontString or not Addon or not Addon.GODMODEDurationBinding then return false end
    local ok, bound = pcall(Addon.GODMODEDurationBinding.Bind, Addon.GODMODEDurationBinding,
        button, fontString, {themeID='auras', actionBarColors=true})
    return ok and bound == true
end
