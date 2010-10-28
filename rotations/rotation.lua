-- We can assume 1.5 sec GCD because we'll never have enough haste to fit 3 GCDs between C.Stikes
local GCD = 1.5;

-- Priority lists
local PRIORITY_J_AS		= { J, AS, CO, HW };	--, HOW };
local PRIORITY_AS_J		= { AS, J, CO, HW };	--, HOW };
local PRIORITY_NO_J		= { AS, CO, HW };		--, HOW };

-- Log a message
local info = function(x)
	--DEFAULT_CHAT_FRAME:AddMessage(x);
end

local latency = function()
	local _, _, lag = GetNetStats();
	return lag/1000.0;
end

-- Assign an ability to the CS slot
local CrusaderStrikeSlot = function(t, spellinfo, state)
	info("    CS slot (hp: " .. state:GetHolyPower() .. ")");
	state:SetCooldown(CS, t + spellinfo:GetCooldown(CS));
	state:SetHolyPower(math.min(state:GetHolyPower()+1, 3));
	return CS;
end

-- Assign an ability to slot X or Y
local SlotXorY = function(t, spellinfo, state, slotX)
	info("    Slot " .. (slotX and "X" or "Y") .. " (hp: " .. state:GetHolyPower() .. ")");
	
	local sacredDuty = state:IsActive(SD, t);
	
	-- Initial application of ShoR to get HS up and running
	if(not state:IsActive(HS, t)) and (state:GetHolyPower() > 0) then
		info("      No HS; initial application of ShoR");
		state:SetExpiration(HS, t + spellinfo:GetExpiration(HS));
		state:SetExpiration(SD, nil);		-- ShoR consumes SD
		state:SetHolyPower(0);
		return SHOR;
	end

	-- 3 HP: if SD is not up, try J->SHOR if J is off cooldown, or AS->SHOR if AS is off cooldown. Otherwise do SHOR followed by whatever is off coodown.
	if(state:GetHolyPower() == 3) then
		info("      3 HP branch (SD active: " .. (state:IsActive(SD, t) and "true" or "false") .. ")");		
		if(slotX) then
			if(not sacredDuty) and (not state:IsOnCooldown(J, t)) then
				info("        J!");
				state:SetCooldown(J, t + spellinfo:GetCooldown(J));
				return J;
			elseif(not state:IsOnCooldown(AS, t)) then
				info("        AS!");
				state:SetCooldown(AS, t + spellinfo:GetCooldown(AS));
				return AS;
			else
				info("        ShoR (X)!");
				state:SetExpiration(HS, t + spellinfo:GetExpiration(HS));
				state:SetExpiration(SD, nil);	-- ShoR consumes SD
				state:SetHolyPower(0);
				return SHOR;
			end
		else
			-- If we got to slot Y and we still have 3 HP, we need to use it before the next CS/HOR
			info("        ShoR (Y)!");
			state:SetExpiration(HS, t + spellinfo:GetExpiration(HS));
			state:SetExpiration(SD, nil);	-- ShoR consumes SD
			state:SetHolyPower(0);
			return SHOR;
		end
	end
	
	info("      Priority list (SD active: " .. (state:IsActive(SD, t) and "true" or "false") .. "), last: " .. state:GetLastUsed());

	-- 0-2 HP: long cooldown priority list. If slot X ability was IDLE, slot Y ability cannot be a Judgement
	local priority;
	if(slotX) or (state:GetLastUsed() ~= IDLE) then
		if(not state:IsActive(SD, t)) then
			priority = PRIORITY_J_AS;
		else
			priority = PRIORITY_AS_J;
		end
	else
		priority = PRIORITY_NO_J;
	end
	
	local s = "";
	local codes = { };
	codes[AS] = "AS";
	codes[J] = "J";
	codes[HW] = "HW";
	codes[HOW] = "HOW";
	codes[CO] = "CO";
	codes[CS] = "CS";
	
	for i=1,#priority do
		local p = priority[i];
		s = s .. " " .. codes[p] .. ":" .. (state:IsOnCooldown(p, t) and format("%4.2f", state:GetCooldown(p)-t) or "+");
	end
	info("        *" .. s);

	local ability = state:GetByPriority(t, priority);
	info("          Ability: '" .. ability .. "'");
	state:SetCooldown(ability, t + spellinfo:GetCooldown(ability));
	return ability;
end

-- Get the next 'count' abilities based on what's on the cooldown
local GetNext = function(this, count, time, spellinfo, originalState)
	local state = originalState:Copy();
	local lag = latency();
	local t = time+lag*2;

	-- Figure out the number of full GCDs before the next CS
	local slot = 0;								-- 0: CS, 1: slot X, 2: slot Y
	local cs = state:GetCooldown(CS);
	if(cs) and (cs > t) then
		slot = mod(math.floor((t-cs)/GCD + 3)+1, 3);		
		--info("[|cFFFFD000Angeli Dei / rotation|r] Starting slot=" .. slot .. " t-cs=" .. (t-cs));
	end
	
	info("[|cFFFFD000Angeli Dei / rotation|r] Starting simulation (#: " .. count .. ", s: " .. slot .. ", t-cs=" .. format("%4.3f", t-cs+4.5) .. ")");
	
	local result = { };	
	for i=1,count do
		info("  Iteration #" .. i .. " (S" .. slot .. " t=" .. format("%4.2f", t) .. ")");
		local info = { };
		if(slot == 0) then
			info.ability = CrusaderStrikeSlot(t, spellinfo, state);
		elseif(slot == 1) then
			info.ability = SlotXorY(t, spellinfo, state, true);
		else
			info.ability = SlotXorY(t, spellinfo, state, false);
		end
		info.time = t;
		result[i] = info;
		state:SetLastUsed(info.ability);
		t = t + GCD + lag;
		slot = mod(slot+1, 3);
	end

	return result;
end

-- Constructor
function CreateRotation()
	local t = { };
	
	t.GetNext = GetNext;
	
	return t;
end
