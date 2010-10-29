-- Return codes for ApplyEvent()
local IGNORE = 0;
local RECALCULATE = 1;
local SHIFT = 2;

--local Copy = function(this)
	--local t2 = { };
	--for k,v in pairs(this) do 
	--	t2[k] = v;
	--end
	--return t2;
--end

-- Create a deep copy of the state
local Copy = function(this)
	local lookup_table = { };
	local function _copy(this)
		if type(this) ~= "table" then
			return this;
		elseif lookup_table[this] then
			return lookup_table[this];
		end
		local new_table = {};
		lookup_table[this] = new_table;
		for index, value in pairs(this) do
			new_table[_copy(index)] = _copy(value);
		end
		return setmetatable(new_table, getmetatable(this));
	end
	return _copy(this);
end

-- Set the cooldown expiration time for the given ability
local SetCooldown = function(this, spellID, time)
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFC000Angeli Dei / state|r] SetCooldown(" .. (spellID or "?") .. ", " .. (time or "?") .. ")");
	this.cooldowns[spellID] = time;
end

-- Get the cooldown expiration time for the given ability
local GetCooldown = function(this, spellID)
	return this.cooldowns[spellID];
end

-- Return true if the ability is on cooldown
local IsOnCooldown = function(this, spellID, time)
	local t = this.cooldowns[spellID];
	return (t) and (time < t);
end

-- Set the expiration time for the given effect
local SetExpiration = function(this, spellID, time)
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFC000Angeli Dei / state|r] SetExpiration(" .. (spellID or "?") .. ", " .. (time or "?") .. ")");
	this.effects[spellID] = time;
end

-- Get the expiration time for the given effect
local GetExpiration = function(this, spellID)
	return this.effects[spellID];
end

-- Return true if the effect is active
local IsActive = function(this, spellID, time)
	local t = this.effects[spellID];
	local x = (t) and (time < t);
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFC000Angeli Dei / state|r] IsActive(" .. (spellID or "?") .. ", " .. (time or "?") .. "): " .. (x and "true" or "false"));

	return (t) and (time < t);
end

-- Get the current holy power
local GetHolyPower = function(this)
	return this.holyPower;
end;

-- Set the current holy power
local SetHolyPower = function(this, n)
	this.holyPower = n;
end

-- Get the buff expiration time
local buffExpiration = function(spellID)
	local _, _, _, _, _, _, expirationTime = UnitBuff("player", GetSpellInfo(spellID));
	return expirationTime;
end

-- Figure out whether we need to re-run the simulation because
-- the health of the target has crossed the 20% mark in either direction
local checkLowHealth = function(this)
	local lowHealthNow = IsUsableSpell(HOW);
	if(lowHealthNow and this.lowHealth) or ((not lowHealthNow) and (not this.lowHealth)) then
		return IGNORE;
	else
		--print("[checkLowHealth] " .. (this.lowHealth and "yes" or "no") .. " --> " .. (lowHealthNow and "yes" or "no"));
		this.lowHealth = lowHealthNow;
		return RECALCULATE;
	end
end

-- Get the most important of the two return codes
local function max(a, b)
	return (a > b) and a or b;
end

-- Update the state using the data of a combat log event.
-- Return 0 if the event was ignorable, 1 if the icons should be shifted,
-- or 2 if the rotation should be recalculated without shifting the icons
local ApplyEvent = function(this, event, spellID, powerType, spellinfo)
	-- Fascinating fact of the day: we cannot measure HoPo at this point. Here's the scenario:
	--   Crusader Strike at 2 HoPo, new HoPo value inside the state object is 3.
	--   The rotation predicts a ShoR
	--   Grand Crusader procs. As far as the client is concerned, HoPo is still 2.
	--   The rotation predicts no ShoR
	--   HoPo finally increases to 3
	--   A new ability is used and the rotation predicts ShoR again
	-- This produces extra jitter we don't need, so I am moving HoPo measurements to SPELL_CAST_SUCCESS
	--this:SetHolyPower(UnitPower("player", 9));
	
	-- Update the low health status if the player target changes
	if(event == "PLAYER_TARGET_CHANGED") then
		return checkLowHealth(this);
	end

	-- All instants
	if(event == "SPELL_CAST_SUCCESS") then
		-- Take target health changes into account
		local low = checkLowHealth(this);
		
		-- HOR is cast twice in a row (one physical single-target, one holy AOE).
		-- If it's cast too soon after the last cast, we'll pretend it never happened.
		-- Note that this means we have to execute this code BEFORE anything else is done.
		if(spellID == HOR) then
			local lastHOR = this.last[spellID];
			if(lastHOR) and (GetTime() - lastHOR < 1.0) then
				return max(low, IGNORE);
			end
		end
		
		this:SetHolyPower(UnitPower("player", 9));
		local result = IGNORE;
		local known = spellinfo:IsKnownSpell(spellID);
		
		-- Keep track of the last spellcast
		if(known) then
			this:SetLastUsed(spellID);
		end
		
		-- We know that CS will always generate 1 HP, therefore we can adjust our value in advance
		if(spellID == CS) or (spellID == HOR) then
			this:SetHolyPower(math.min(this:GetHolyPower()+1, 3));
			result = RECALCULATE;
		end
		-- Same with ShoR/Inq and Holy Shield
		if(spellID == SHOR) or (spellID == INQ) then
			this:SetExpiration(HS, GetTime() + spellinfo:GetExpiration(HS));
			result = RECALCULATE;
		end
		
		-- HOR and CS have a shared cooldown
		if(spellID == CS) or (spellID == HOR) then
			local start = GetTime();	-- GetSpellCooldown(spellID);			
			this:SetCooldown(CS, start+spellinfo:GetCooldown(CS));
			this:SetCooldown(HOR, start+spellinfo:GetCooldown(HOR));
			result = SHIFT;
		elseif(known) then
			local start = GetTime();	-- GetSpellCooldown(spellID);			
			--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFF0080Angeli Dei / state|r] ApplyEvent: '" .. spellID .. "' start=" .. start .. " cd=" .. spellinfo:GetCooldown(spellID));
			this:SetCooldown(spellID, start+spellinfo:GetCooldown(spellID));
			result = SHIFT;
		end;

		-- Actual spell delay reporting
		--[[
		if(known) then
			local start = GetTime();
			if(this.last[spellID] ~= nil) then
				local _,_,lag = GetNetStats();
				lag = lag/1000.0;
				DEFAULT_CHAT_FRAME:AddMessage("[|cFF00FFFFAngeli Dei|r] Last '" .. spellID .. "': " 
					.. format("%4.3f", start-this.last[spellID]-spellinfo:GetCooldown(spellID)) 
					.. " (latency: " .. format("%4.3f", lag) .. ")");
			end
			this.last[spellID] = start;
		end
		--]]
		
		-- We'll use it to filter out the second HOR
		this.last[spellID] = GetTime();
		return max(low, result);
	end
	
	if(event == "SPELL_AURA_APPLIED") or (event == "SPELL_AURA_REFRESHED") then
		if(spellID == SD) or (spellID == HS) or (spellID == JOTW) then
			local expiration = buffExpiration(spellID);
			--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFF00D0Angeli Dei / state|r] ApplyEvent: '" .. spellID .. "' exp=" .. format("%4.2f", expiration));
			this:SetExpiration(spellID, expiration);
			return IGNORE;		-- We do NOT want to update our rotation on unimportant buffs
			--return (spellID == SD) and 0 or 2;
		end
		if(spellID == GC) then
			this:SetCooldown(AS, nil);
			return RECALCULATE;
		end
		
		return IGNORE;
	end
	
	if(event == "SPELL_ENERGIZE") then
		-- By the time EG procs, the client will know the current HoPo
		if(spellID == EG) then
			this:SetHolyPower(UnitPower("player", 9));
			return RECALCULATE;
		end
	end
	
	--if(event == "SPELL_AURA_REMOVED") then
	--	if(spellID == SD) or (spellID == HS) then
	--		this:SetExpiration(spellID, nil);
	--		return RECALCULATE;
	--	end
	--end

	return IGNORE;
end

-- Get the first spell from the list that isn't on cooldown
local GetByPriority = function(this, time, list)
	for i=1,#list do
		if(not this:IsOnCooldown(list[i], time)) then
			return list[i];
		end
	end
	
	return IDLE;
end

-- Return the last ability used (can be IDLE).
local GetLastUsed = function(this)
	return this.lastUsed;
end

-- Set the last ability used. This can be used to indicate empty GCDs
local SetLastUsed = function(this, spellID)
	this.lastUsed = spellID;
	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFF0080Angeli Dei / state|r] Last used: '" .. spellID .. "'");
end

-- Check whether the target is low on health
local IsLowHealth = function(this)
	return this.lowHealth;
end

-- Get the duration of the global cooldown
local GCD = function(this)
	return 1.5;
end

-- Constructor
function CreateState()
	local t = { };
	
	t.cooldowns = { };
	t.effects = { };
	t.holyPower = 0;
	t.last = { };
	t.lastUsed = "UNKNOWN";
	t.lowHealth = false;
	
	t.Copy = Copy;
	t.SetCooldown = SetCooldown;
	t.GetCooldown = GetCooldown;
	t.IsOnCooldown = IsOnCooldown;
	t.SetExpiration = SetExpiration;
	t.GetExpiration = GetExpiration;
	t.IsActive = IsActive;
	t.GetHolyPower = GetHolyPower;
	t.SetHolyPower = SetHolyPower;
	t.ApplyEvent = ApplyEvent;
	t.GetByPriority = GetByPriority;
	t.GetLastUsed = GetLastUsed;
	t.SetLastUsed = SetLastUsed;
	t.IsLowHealth = IsLowHealth;
	t.GCD = GCD;

	--DEFAULT_CHAT_FRAME:AddMessage("[|cFFFFC000Angeli Dei / state|r] Created");
	
	return t;
end
