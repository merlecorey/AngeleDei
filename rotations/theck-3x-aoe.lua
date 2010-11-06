local PRIORITY_939_AOE				= { HOR, J, AS, HW, CO };	-- SHOR > all
local PRIORITY_939_AOE_CONSECRATE	= { HOR, CO, HW, AS, J };	-- AS > SHOR > J (hardcoded)

-- Get the priority list for this rotation
local GetPriorityAOE = function(this, state, settings, spellinfo)
	return PRIORITY_939_AOE;
end

-- Choose the next ability (AOE flavor)
local ChooseNextAOE = function(this, t, spellinfo, state, priority, settings)

	-- Initial application of Holy Shield
	local hopo = state:GetHolyPower();
	if(hopo > 0) and (not state:IsActive(HS, t)) and (settings.holyShield) then
		return SHOR;
	end

	-- Consecration is enabled. Prioritize SHOR over Judements and empty slots
	if(settings.consecration and ((not settings.hallowedGround) or spellinfo:HasHallowedGround())) then
		local candidate = state:GetByPriority(t+priority, PRIORITY_939_AOE_CONSECRATE);
		
		-- HPx3 SHOR > J
		if((candidate == J) or (candidate == IDLE)) and (hopo == 3) then
			return SHOR
		end

		return candidate;
	end
	
	-- Consecration is not enabled. Use a low-Consecration priority
	return state:GetByPriority(t+priority, PRIORITY_939_AOE);
end

-- This is a copy of the single-target 939 rotation with HOR replacing CS
function CreateRotationAOE939()
	local t = CreateRotationTheck939();
	
	--t.GetPriority = GetPriorityAOE;
	t.ChooseNext = ChooseNextAOE;
	t.name = TITLE_AOE_939;
	t.description = SUBTITLE_AOE_939;
	t.singleTarget = false;

	return t;
end
