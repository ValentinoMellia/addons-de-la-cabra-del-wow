local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...

-- BetterBlizzPlates compatibility bridge.
-- ISOLATED: never changes Threat Plates/Plater state and never rewrites BBP SavedVariables.
local Bridge = {}
Addon.ForeverBetterBlizzPlatesBridge = Bridge

local function loaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok,v=pcall(C_AddOns.IsAddOnLoaded,'BetterBlizzPlates'); if ok then return v and true or false end
    end
    if IsAddOnLoaded then
        local ok,v=pcall(IsAddOnLoaded,'BetterBlizzPlates'); if ok then return v and true or false end
    end
    return false
end

local function providerEnabled()
    local cfg=Addon.GetCompatibilityProvider and Addon:GetCompatibilityProvider('betterblizzplates')
    local c=Addon.db and Addon.db.global and Addon.db.global.compatibilityCenter
    return c and c.enabled~=false and type(cfg)=='table' and cfg.enabled==true
end

local function bbpOwns()
    return Addon.CompatibilityProviderOwnsScope
       and Addon:CompatibilityProviderOwnsScope('betterblizzplates','nameplates') or false
end

local function unitFrame(plate)
    return plate and (plate.UnitFrame or plate.unitFrame) or nil
end

local function setAurasShown(frame,shown)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local BBP=rawget(_G,'BBP')
    if type(BBP)=='table' and type(BBP.SetNameplateAurasShown)=='function' then
        pcall(BBP.SetNameplateAurasShown,frame,shown)
        return
    end
    -- Fallback only masks known Blizzard aura containers; no BBP options are changed.
    for _,key in ipairs({'BuffFrame','DebuffFrame','AuraFrame','AurasFrame'}) do
        local a=frame[key]
        if a and a.SetAlpha then pcall(a.SetAlpha,a,shown and 1 or 0) end
    end
end

function Bridge:IsActive()
    return loaded() and type(rawget(_G,'BetterBlizzPlatesDB'))=='table'
end

function Bridge:ApplyToPlate(plate)
    if not self:IsActive() or not providerEnabled() then return false end
    local frame=unitFrame(plate); if not frame then return false end
    if bbpOwns() then
        setAurasShown(frame,true)
        return false
    end
    -- GODMODE owns auras: hide only BBP/native aura presentation.
    -- BBP health bars, names, castbars, colors and other features remain untouched.
    setAurasShown(frame,false)
    return true
end

function Bridge:ApplyOwnership()
    if not self:IsActive() then return false end
    local plates=C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    for _,plate in ipairs(plates) do self:ApplyToPlate(plate) end
    return providerEnabled() and not bbpOwns()
end

function Bridge:Refresh() return self:ApplyOwnership() end
function Bridge:OwnsCooldown() return false end

local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('PLAYER_ENTERING_WORLD')
f:RegisterEvent('NAME_PLATE_UNIT_ADDED')
f:RegisterEvent('ADDON_LOADED')
f:SetScript('OnEvent',function(_,event,arg)
    if event=='ADDON_LOADED' and arg~='BetterBlizzPlates' then return end
    if event=='NAME_PLATE_UNIT_ADDED' then
        if not providerEnabled() then return end
        local plate=C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(arg)
        if plate then Bridge:ApplyToPlate(plate) end
        return
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,function() Bridge:ApplyOwnership() end)
    else Bridge:ApplyOwnership() end
end)
