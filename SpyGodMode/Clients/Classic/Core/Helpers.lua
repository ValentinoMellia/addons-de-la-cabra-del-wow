local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 11508 and __sgmBuild ~= 11509 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local band=bit and bit.band or bit32 and bit32.band
function SGM:Print(t) DEFAULT_CHAT_FRAME:AddMessage("|cffffb000Spy God Mode:|r "..tostring(t)) end
function SGM:ShortName(n) if not n then return nil end; return (Ambiguate and Ambiguate(n,"short")) or n:match("^[^-]+") end
function SGM:IsHostilePlayer(flags) return flags and band(flags,COMBATLOG_OBJECT_TYPE_PLAYER)~=0 and band(flags,COMBATLOG_OBJECT_REACTION_HOSTILE)~=0 end
function SGM:Now() return time() end
function SGM:Ago(ts) local d=math.max(0,time()-(ts or time())); if d<60 then return d.."s" elseif d<3600 then return math.floor(d/60).."m" elseif d<86400 then return math.floor(d/3600).."h" else return math.floor(d/86400).."d" end end
function SGM:ClassColor(class)
 local key=type(class)=="string" and class:upper() or ""
 local colors={
  WARRIOR={0.78,0.61,0.43},
  PALADIN={0.96,0.55,0.73},
  HUNTER={0.67,0.83,0.45},
  ROGUE={1.00,0.96,0.41},
  PRIEST={1.00,1.00,1.00},
  SHAMAN={0.00,0.44,0.87},
  MAGE={0.25,0.78,0.92},
  WARLOCK={0.53,0.53,0.93},
  DRUID={1.00,0.49,0.04},
  DEATHKNIGHT={0.77,0.12,0.23},
  MONK={0.00,1.00,0.60},
  DEMONHUNTER={0.64,0.19,0.79},
  EVOKER={0.20,0.58,0.50},
 }
 local c=colors[key]
 if c then return c[1],c[2],c[3] end
 local api=RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
 return api and api.r or 1,api and api.g or .25,api and api.b or .25
end
function SGM:Zone() return GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or "" end

local sanctuaryNames={
 ["Shattrath City"]=true,["Shattrath"]=true,["Dalaran"]=true,["Dornogal"]=true,
 ["Valdrakken"]=true,["Oribos"]=true,["The Vindicaar"]=true,["Sanctum of the Stars"]=true,
 ["The Veiled Stair"]=true,["Shrine of Seven Stars"]=true,["Shrine of Two Moons"]=true,
}
local allianceCities={
 ["Stormwind City"]=true,["Ironforge"]=true,["Darnassus"]=true,["The Exodar"]=true,["Boralus"]=true,["Gilneas City"]=true,
}
local hordeCities={
 ["Orgrimmar"]=true,["Thunder Bluff"]=true,["Undercity"]=true,["Silvermoon City"]=true,["Dazar'alor"]=true,
}
function SGM:IsEnemyCity()
 -- Neutral/sanctuary cities must never activate Enemy City Mode or its alert.
 if self:IsSanctuaryZone() then return false end
 local zone=self:Zone()
 local faction=self.playerFaction or (UnitFactionGroup and UnitFactionGroup("player"))
 if faction=="Alliance" then return hordeCities[zone]==true end
 if faction=="Horde" then return allianceCities[zone]==true end
 return false
end
function SGM:IsSanctuaryZone()
 local pvpType
 if GetZonePVPInfo then pvpType=GetZonePVPInfo() end
 if pvpType=="sanctuary" then return true end
 return sanctuaryNames[self:Zone()]==true
end
function SGM:CanDetectHere()
 -- Sanctuary/neutral zones always suppress detection and sounds, even when Enemy City Mode is enabled.
 if self:IsSanctuaryZone() then return false end
 if self.cfg and self.cfg.enemyCityMode then return true end
 return true
end

function SGM:SafeSound(kind)
 if not self.cfg or not self.cfg.sound then return false end
 if self.cfg.soundOnlyKos and kind~="KOS" then return false end
 if self.cfg.soundProfile=="SILENT" then return false end
 local addonFolder="SpyGodMode"
 local base="Interface\\AddOns\\"..addonFolder.."\\Media\\Audio\\"
 local profile=self.cfg.soundProfile or "CLASSIC"
 local files={NEARBY="sgm-danger.ogg",STEALTH="sgm-stealth.ogg",KOS="sgm-kos.ogg",HIGH="sgm-high-threat.ogg",ADD="sgm-list-add.ogg",REMOVE="sgm-list-remove.ogg",TARGET="sgm-high-threat.ogg",SOS="sgm-high-threat.ogg"}
 local file=base..(files[kind] or files.NEARBY)
 if profile=="ALARM" and kind~="ADD" and kind~="REMOVE" then file=base.."sgm-kos.ogg" end
 if profile=="STEALTH" and kind=="NEARBY" then file=base.."sgm-stealth.ogg" end
 local ok,played=pcall(PlaySoundFile,file,"Master")
 if ok and played~=false then return true end
 -- Some clients resolve addon media more reliably with forward slashes.
 local slashFile=file:gsub("\\","/")
 ok,played=pcall(PlaySoundFile,slashFile,"Master")
 if ok and played~=false then return true end
 local sk=SOUNDKIT or {}
 local ids={NEARBY=sk.ALARM_CLOCK_WARNING_3 or sk.RAID_WARNING or 8959,STEALTH=sk.IG_QUEST_FAILED or 847,KOS=sk.RAID_WARNING or 8959,HIGH=sk.READY_CHECK or 8960,ADD=856,REMOVE=857,TARGET=sk.RAID_WARNING or 8959,SOS=sk.RAID_WARNING or 8959}
 local ok2,played2=pcall(PlaySound,ids[kind] or ids.NEARBY,"Master")
 return ok2 and played2~=false
end
