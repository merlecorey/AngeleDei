local PRIORITY_939_SINGLE_TARGET			= { CS, J, AS, HW, CO };
local PRIORITY_939_SINGLE_TARGET_CONSECRATE	= { CS, J, AS, CO, HW };
local PRIORITY_939_SINGLE_TARGET_LOW_HEALTH	= { CS, J, HOW, AS, HW, CO };

-- Sort the cooldowns by expiration. Return a list of pairs:
-- { { ability, cooldown }, ... }. Cooldowns that expire before 't'
-- are set to 't'
local function sortByExpiration(t, allowHPSink, allowHOW, state, spellinfo)
	local result = { };
	local cds = spellinfo:GetAbilitiesWithCooldowns();

	for i=1,#cds do
		local name = cds[i];
		local cooldown = state:GetCooldown(name);
		-- If HoW is not allowed, don't consider it at all
		if(name ~= HOW) or (allowHOW) then
			--print("[sortByExpiration] " .. (name or "?") .. " = " .. (cooldown or "?") .. " (" .. #result .. ")");
			local cd = ((cooldown == nil) or (cooldown < t)) and t or cooldown;
			local info = { };
			info.name = name;
			info.cooldown = cd;
			result[#result+1] = info;
		end
	end

	-- Add the HoPo sink move to the list if we are allowed to do so
	if(allowHPSink) then
		local info = { };
		info.name = SHOR;
		info.cooldown = t;
		result[#result+1] = info;
	end
	
	--for i=1,#result do
	--	print("[sortByExpiration] " .. i .. "/" .. #result .. ": " .. result[i].name .. " @ " .. result[i].cooldown);
	--end

	table.sort(result, function(x, y)
		--print("[sort] x=" .. (x and x.name or "?") .. " y=" .. (y and y.name or "?"));
		--if(x == nil) then
		--	return -1;
		--elseif(y == nil) then
		--	return 1;
		--end
		return x.cooldown < y.cooldown;
	end);
	
	return result;
end

-- Create an { ability, time } structure.
local function pack(ability, time, idle)
	local info = { };
	info.ability = ability;
	info.time = time;
	if(idle ~= nil) then
		info.idle = idle;
	end
	
	--print("[pack] " .. ability .. ", " .. time .. ", " .. (idle or "?"));
	
	return info;
end

-- Insert IDLE abilities in the middle of long pauses
local function insertIDLE(result, t0, gcd, delay)
	local resultWithPauses = { };
	
	local previous = t0;
	for i=1,#result do
		local x = result[i];
		local dt = x.time - previous - gcd;
		local n = math.floor(dt / (gcd - delay/2));
		--print("[insertIDLE] dt(" .. (i-1) .. "->" .. i .. " = " .. format("%4.3f", dt) .. " [|cFF00FFFF" .. n .. "]");
		if(n <= 0) then
			-- No pauses
		elseif(n == 1) then
			-- One pause
			resultWithPauses[#resultWithPauses+1] = pack(IDLE, previous+gcd, dt);
		else -- if(n >= 2) then
			-- Two pauses
			resultWithPauses[#resultWithPauses+1] = pack(IDLE, previous+gcd, dt/2);
			resultWithPauses[#resultWithPauses+1] = pack(IDLE, previous+gcd+(dt/2), dt/2);
		end
	
		resultWithPauses[#resultWithPauses+1] = x;
		previous = result[i].time;
	end
	
	return resultWithPauses;
end

-- Apply the given ability to the state object
local function applyAbility(name, t, state, spellinfo)
	if(name == SHOR) then
		state:SetExpiration(HS, t + spellinfo:GetExpiration(HS));
		state:SetExpiration(SD, nil);								-- ShoR consumes SD
		state:SetHolyPower(0);
		--print("[applyAbility] |cFFFF0000" .. name .. "|r (" .. spellinfo:GetCooldown(name) .. ")");
	elseif(name == CS) or (name == HOR) then
		local hopo = state:GetHolyPower();
		state:SetCooldown(CS, t + spellinfo:GetCooldown(CS));		-- Shared CS / HOR cooldown
		state:SetCooldown(HOR, t + spellinfo:GetCooldown(HOR));
		state:SetHolyPower(math.min(hopo+1, 3));
		--print("[applyAbility] |cFFFF0000CS/HOR|r: " .. spellinfo:GetCooldown(CS) .. ": HOPO " .. hopo .. " --> " .. state:GetHolyPower());		
	else
		state:SetCooldown(name, t + spellinfo:GetCooldown(name));
		--print("[applyAbility] |cFFFF0000" .. name .. "|r (" .. spellinfo:GetCooldown(name) .. ")");
	end
end

-- Choose the next ability (single-target flavor)
local ChooseNext = function(this, t, spellinfo, state, priority, settings)
	local hopo = state:GetHolyPower();
	
	if(hopo > 0) and (not state:IsActive(HS, t)) and (settings.holyShield) then
		-- Initial application of Holy Shield
		return SHOR;
	elseif(hopo == 3) then
		-- 3 HoPo ShoR
		return SHOR;
	end

	return state:GetByPriority(t+priority, this:GetPriority(state, settings, spellinfo));
end

-- Get the next 'count' abilities based on what's on the cooldown
local GetNext = function(this, count, time, spellinfo, originalState, settings)
	local state = originalState:Copy();
	local result = { };
	local gcd = state:GCD();
	local delay = settings.delay/1000.0;
	local priority = settings.priority/1000.0;
	local t = time + gcd;
	local t0 = t;
	
	--print("[GetNext] gcd=" .. gcd .. " delay=" .. delay .. " priority=" .. priority);
	
	for i=1, count do
		-- Get list of { name, cooldown } pairs sorted by cooldown
		local list = sortByExpiration(t, true, state:IsLowHealth(), state, spellinfo);
		
		--for j=1,#list do
		--	print("  " .. j .. ": " .. list[j].name .. " @ " .. format("%4.3f", list[j].cooldown - t0));
		--end
		
		local tNext = list[1].cooldown;
		--print("[GetNext] Iteration " .. i .. ", time=" .. format("%4.3f", t - t0) .. ", HOPO " .. hopo 
		--	.. ", Tnext=" .. format("%4.3f", tNext - t0) .. " (|cFFFF8080" .. list[1].name .. "|r)"
		--	.. ", SHOR: " .. (shorAllowed and "yes" or "no"));

		
		-- Figure out the slot for tNext and the corresponding ability
		local ability = this:ChooseNext(tNext, spellinfo, state, priority, settings);
	
		-- Adjust the state according to the ability we've chosen
		applyAbility(ability, tNext, state, spellinfo);
		
		-- If this is an idle slot, make sure the wait time is specified
		-- so that the idle icon can be shifted properly
		local idle = nil;
		if(ability == IDLE) then
			idle = gcd;
		end

		result[i] = pack(ability, tNext, idle);
		
		-- The next GCD is already taken so we'll skip it
		t = tNext + gcd;
	end
	
	-- Insert IDLE "abilities" in the middle of long pauses	
	local resultWithPauses = insertIDLE(result, time, gcd, delay);
	--local resultWithPauses = result;	
	
	-- Make sure we return only 'count' elements
	while(#resultWithPauses > count) do
		table.remove(resultWithPauses, #resultWithPauses);
	end
	
	return resultWithPauses;
end

-- Get the priority list for this rotation
local GetPriority = function(this, state, settings, spellinfo)
	if(state:IsLowHealth()) then
		return PRIORITY_939_SINGLE_TARGET_LOW_HEALTH;
	elseif(settings.consecration and ((not settings.hallowedGround) or spellinfo:HasHallowedGround())) then
		return PRIORITY_939_SINGLE_TARGET_CONSECRATE;
	else
		return PRIORITY_939_SINGLE_TARGET;
	end
end

-- Check whether simulation should be re-run for this rotation when the target changes
local IsTargetSensitive = function(this)
	return this.targetSensitive;
end

-- Constructor
function CreateRotationTheck939()
	local t = { };
	
	t.GetNext = GetNext;
	t.GetPriority = GetPriority;
	t.ChooseNext = ChooseNext;
	t.IsTargetSensitive = IsTargetSensitive;
	t.name = TITLE_SINGLE_939;
	t.description = SUBTITLE_SINGLE_939;
	t.singleTarget = true;
	t.targetSensitive = true;

	return t;
end
