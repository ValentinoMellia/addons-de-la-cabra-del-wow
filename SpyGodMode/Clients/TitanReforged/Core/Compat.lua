local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 38002 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...

local _,build,_,interfaceVersion=GetBuildInfo()
SGM.interfaceVersion=tonumber(interfaceVersion) or 0
SGM.buildNumber=tonumber(build) or 0
SGM.isRetail=SGM.interfaceVersion>=100000
SGM.isMidnight=SGM.interfaceVersion>=120000
SGM.isClassicEra=SGM.interfaceVersion>=10000 and SGM.interfaceVersion<20000
SGM.isTBC=SGM.interfaceVersion>=20000 and SGM.interfaceVersion<30000

function SGM:IsSecret(value)
 return issecretvalue and issecretvalue(value) or false
end

function SGM:SafeValue(value)
 if self:IsSecret(value) then return nil end
 return value
end

function SGM:SafeCall(fn,...)
 if type(fn)~="function" then return nil end
 local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
 if not ok then return nil end
 if self:IsSecret(a) then return nil end
 return a,b,c,d,e,f,g,h
end

function SGM:GetSpellTexture(spellID)
 if C_Spell and C_Spell.GetSpellTexture then
  return self:SafeCall(C_Spell.GetSpellTexture,spellID)
 end
 if GetSpellTexture then return self:SafeCall(GetSpellTexture,spellID) end
end

function SGM:GetUnitFullName(unit)
 local name,realm
 if UnitFullName then name,realm=self:SafeCall(UnitFullName,unit) end
 if not name and GetUnitName then name=self:SafeCall(GetUnitName,unit,true) end
 if not name then name=self:SafeCall(UnitName,unit) end
 if not name or name=="" then return nil end
 if realm and realm~="" and not tostring(name):find("-",1,true) then return name.."-"..realm end
 return name
end

function SGM:IsValidEnemyUnit(unit)
 if not unit or not UnitExists or not self:SafeCall(UnitExists,unit) then return false end
 if not self:SafeCall(UnitIsPlayer,unit) then return false end
 if self:SafeCall(UnitIsUnit,"player",unit) then return false end

 -- Opposing faction is the primary test. UnitCanAttack becomes false for
 -- unflagged enemy players on modern clients, so it cannot be used alone.
 local playerFaction=self.playerFaction or self:SafeCall(UnitFactionGroup,"player")
 local unitFaction=self:SafeCall(UnitFactionGroup,unit)
 if (playerFaction=="Alliance" or playerFaction=="Horde") and
    (unitFaction=="Alliance" or unitFaction=="Horde") then
  return playerFaction~=unitFaction
 end

 -- Fallbacks for clients/unit tokens that do not expose faction reliably.
 if self:SafeCall(UnitIsEnemy,"player",unit)==true then return true end
 if self:SafeCall(UnitCanAttack,"player",unit)==true then return true end
 local reaction=self:SafeCall(UnitReaction,"player",unit)
 return type(reaction)=="number" and reaction<=3
end
