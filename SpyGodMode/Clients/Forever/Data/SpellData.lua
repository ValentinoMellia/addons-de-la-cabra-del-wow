local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
SGM.stealthSpells={[1784]=true,[1856]=true,[1857]=true,[26889]=true,[5215]=true,[6783]=true,[9913]=true,[66]=true,[58984]=true,[11327]=true}
