local PRIORITY_X_3HP_SD		= { AS, HW, CO, SHOR };			-- { AS, HW, CO, SHOR, HOW };
local PRIORITY_X_3HP_noSD	= { J, AS, HW, CO, SHOR };		-- { J, AS, HW, CO, HOW, SHOR };
local PRIORITY_XY_02HP		= { AS, J, HW, CO };			-- { J, AS, HW, CO, HOW };

-- Sort the cooldowns by expiration. Return a list of pairs:
-- { { ability, cooldown }, ... }. Cooldowns that expire before 't'
-- are set to 't'
local function sortByExpiration(t, allowHPSink, state, spellinfo)
	local result = { };
	local cds = spellinfo:GetAbilitiesWithCooldowns();

	for i=1,#cds do
		local name = cds[i];
		local cooldown = state:GetCooldown(name);
		--print("[sortByExpiration] " .. (name or "?") .. " = " .. (cooldown or "?") .. " (" .. #result .. ")");
		local cd = ((cooldown == nil) or (cooldown < t)) and t or cooldown;
		local info = { };
		info.name = name;
		info.cooldown = cd;
		result[#result+1] = info;
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

-- Choose an ability for the CS slot
local function slotCS(tNext, spellinfo, state, priority)
	
	-- If it's time to do the next CS but we haven't used up HoPo yet,
	-- don't let it go to waste
	if(state:GetHolyPower() == 3) then
		return SHOR;
	end
	
	return CS;
end

-- Choose an ability for slot X
local function slotX(t, spellinfo, state, priority)
	local hopo = state:GetHolyPower();
	local list;
	
	if(hopo > 0) and (not state:IsActive(HS, t)) then
		-- Initial application of Holy Shield
		return SHOR;
	elseif(hopo == 3) then
		-- 3HP
		if(state:IsActive(SD, t)) then
			list = PRIORITY_X_3HP_SD;
		else
			list = PRIORITY_X_3HP_noSD;
		end
	else
		-- 0..2 HP
		list = PRIORITY_XY_02HP;
	end
	
	return state:GetByPriority(t+priority, list);
end

-- Choose an ability for slot Y
local function slotY(t, spellinfo, state, priority)
	local hopo = state:GetHolyPower();
	local list;
	
	if(hopo > 0) and (not state:IsActive(HS, t)) then
		-- Initial application of Holy Shield
		return SHOR;
	elseif(hopo == 3) then
		-- 3HP
		return SHOR;
	else
		-- 0..2 HP
		list = PRIORITY_XY_02HP;
	end
	
	return state:GetByPriority(t+priority, list);
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
		local hopo = state:GetHolyPower();

		-- We are allowed to use SHOR:
		--     (a) at 3 HP, or...
		--     (b) at 1 or 2 HP if Holy Shield is not active		
		local shorAllowed = (hopo == 3) or ((hopo > 0) and (not state:IsActive(HS, t)));

		-- Get list of { name, cooldown } pairs sorted by cooldown
		local list = sortByExpiration(t, shorAllowed, state, spellinfo);
		
		--for j=1,#list do
		--	print("  " .. j .. ": " .. list[j].name .. " @ " .. format("%4.3f", list[j].cooldown - t0));
		--end
		
		local tNext = list[1].cooldown;
		--print("[GetNext] Iteration " .. i .. ", time=" .. format("%4.3f", t - t0) .. ", HOPO " .. hopo 
		--	.. ", Tnext=" .. format("%4.3f", tNext - t0) .. " (|cFFFF8080" .. list[1].name .. "|r)"
		--	.. ", SHOR: " .. (shorAllowed and "yes" or "no"));

		
		-- Figure out the slot for tNext and the corresponding ability
		local ability = nil;
		local cs = state:GetCooldown(CS) or tNext;
		
		--[[
		if(tNext > cs - gcd + delay) then
			--print("[GetNext]   Slot CS");
			ability = slotCS(tNext, spellinfo, state, priority);
		elseif(tNext >= cs - gcd) and (tNext < cs - gcd + delay) then
			--print("[GetNext]   Slot Y");
			ability = slotY(tNext, spellinfo, state, priority);
		else -- if(tNext < cs - gcd) then
			--print("[GetNext]   Slot X");
			ability = slotX(tNext, spellinfo, state, priority);
		end
		--]]

		local csThreshold = cs - gcd + delay;
		local xThreshold = cs - (2*gcd) + delay;
		--local s = " {CS=" .. format("%4.3f", cs - t0) .. " Tcs=" .. format("%4.3f", csThreshold - t0) .. " Tx=" .. format("%4.3f", xThreshold - t0) .. "}";
		
		if(tNext > csThreshold) then
			--print("[GetNext]   Slot CS" .. s);
			ability = slotCS(tNext, spellinfo, state, priority);
		elseif(tNext <= xThreshold) then
			--print("[GetNext]   Slot X" .. s);
			ability = slotX(tNext, spellinfo, state, priority);
		else -- if(tNext > xThrehold) and (tNext <= csThreshold) then
			--print("[GetNext]   Slot Y" .. s);
			ability = slotY(tNext, spellinfo, state, priority);
		end
		
		-- Adjust the state according to the ability we've chosen
		applyAbility(ability, tNext, state, spellinfo);
		
		result[i] = pack(ability, tNext);
		
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

-- Constructor
function CreateRotationCS45()
	local t = { };
	
	t.GetNext = GetNext;
	t.name = "4.5 sec Crusader Strike";
	t.description = "The old abomination featuring too many empty GCDs. Probably obsolete at this point."
	t.singleTarget = false;
	
	return t;
end
