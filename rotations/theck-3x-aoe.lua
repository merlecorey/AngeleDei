local PRIORITY_939_AOE		= { HOR, J, AS, HW, CO };

-- Get the priority list for this rotation
local GetPriorityAOE = function(this, state)
	return PRIORITY_939_AOE;
end

-- This is a copy of the single-target 939 rotation with HOR replacing CS
function CreateRotationAOE939()
	local t = CreateRotationTheck939();
	
	t.GetPriority = GetPriorityAOE;
	t.name = TITLE_AOE_939;
	t.description = SUBTITLE_AOE_939;
	t.singleTarget = false;

	return t;
end
